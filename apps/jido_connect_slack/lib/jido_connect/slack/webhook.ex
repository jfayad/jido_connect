defmodule Jido.Connect.Slack.Webhook do
  @moduledoc """
  Pure helpers for Slack signed request verification and Events API payloads.
  """

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Webhook, as: CoreWebhook

  @max_skew_seconds 300

  def parse_headers(headers) when is_map(headers) do
    %{
      signature: header(headers, "x-slack-signature"),
      timestamp: header(headers, "x-slack-request-timestamp")
    }
  end

  def verify_signature(body, headers, signing_secret, opts \\ [])

  def verify_signature(_body, _headers, nil, _opts) do
    {:error, Error.auth("Slack signing secret is required", reason: :missing_signing_secret)}
  end

  def verify_signature(_body, _headers, "", _opts) do
    {:error, Error.auth("Slack signing secret is required", reason: :missing_signing_secret)}
  end

  def verify_signature(body, headers, signing_secret, opts)
      when is_binary(body) and is_map(headers) and is_binary(signing_secret) do
    parsed = parse_headers(headers)
    now = Keyword.get(opts, :now, System.system_time(:second))

    with {:ok, timestamp} <- parse_timestamp(parsed.timestamp),
         :ok <- reject_replay(timestamp, now),
         {:ok, base} <- signature_base(body, timestamp) do
      CoreWebhook.verify_hmac_sha256(base, parsed.signature, signing_secret,
        prefix: "v0=",
        missing_signature_message: "Slack request signature is invalid",
        missing_signature_reason: :invalid_signature,
        invalid_signature_message: "Slack request signature is invalid",
        invalid_signature_reason: :invalid_signature
      )
    end
  end

  def verify_request(body, headers, signing_secret, opts \\ []) do
    with {:ok, delivery} <- verify_delivery(body, headers, signing_secret, opts) do
      {:ok, delivery.payload}
    end
  end

  def verify_delivery(body, headers, signing_secret, opts \\ []) do
    with :ok <- verify_signature(body, headers, signing_secret, opts),
         {:ok, payload} <- decode_body(body) do
      with {:ok, delivery} <-
             WebhookDelivery.verified(:slack, %{
               delivery_id: Data.get(payload, "event_id"),
               event: get_in(payload, ["event", "type"]) || Data.get(payload, "type"),
               headers: headers,
               payload: payload,
               duplicate?:
                 CoreWebhook.duplicate?(
                   Data.get(payload, "event_id"),
                   Keyword.get(opts, :seen_delivery_ids, [])
                 ),
               metadata: %{team_id: Data.get(payload, "team_id")}
             }) do
        {:ok, maybe_put_normalized_signal(delivery)}
      end
    end
  end

  def url_verification_challenge(%{"type" => "url_verification", "challenge" => challenge})
      when is_binary(challenge) do
    {:ok, challenge}
  end

  def url_verification_challenge(_payload) do
    {:error,
     Error.provider("Slack payload is not a URL verification challenge",
       provider: :slack,
       reason: :not_url_verification
     )}
  end

  def normalize_signal(%WebhookDelivery{event: event, payload: payload} = delivery) do
    with {:ok, signal} <- normalize_signal(event, payload) do
      {:ok, Map.put(signal, :delivery, delivery_metadata(delivery))}
    end
  end

  def normalize_signal(
        "app_mention",
        %{"type" => "event_callback", "event" => %{"type" => "app_mention"} = event} = payload
      ) do
    {:ok,
     Data.compact(%{
       team_id: Data.get(payload, "team_id"),
       event_id: Data.get(payload, "event_id"),
       channel: Data.get(event, "channel"),
       channel_type: Data.get(event, "channel_type"),
       user: Data.get(event, "user"),
       text: Data.get(event, "text"),
       ts: Data.get(event, "ts"),
       thread_ts: Data.get(event, "thread_ts")
     })}
  end

  def normalize_signal(
        "message",
        %{"type" => "event_callback", "event" => %{"type" => "message"} = event} = payload
      ) do
    with :ok <- reject_message_subtype(event),
         :ok <- require_message_channel_type(event, [nil, "channel", "group", "im", "mpim"]) do
      {:ok, message_signal(payload, event)}
    end
  end

  def normalize_signal("message.channels", payload) do
    normalize_message_signal(payload, [nil, "channel"])
  end

  def normalize_signal("message.groups", payload) do
    normalize_message_signal(payload, ["group"])
  end

  def normalize_signal("message.im", payload) do
    normalize_message_signal(payload, ["im"])
  end

  def normalize_signal("message.mpim", payload) do
    normalize_message_signal(payload, ["mpim"])
  end

  def normalize_signal("message.thread_reply", payload) do
    normalize_thread_reply_signal(payload)
  end

  def normalize_signal(
        "reaction_added",
        %{"type" => "event_callback", "event" => %{"type" => "reaction_added"} = event} =
          payload
      ) do
    {:ok, reaction_signal(payload, event)}
  end

  def normalize_signal(
        "reaction_removed",
        %{"type" => "event_callback", "event" => %{"type" => "reaction_removed"} = event} =
          payload
      ) do
    {:ok, reaction_signal(payload, event)}
  end

  def normalize_signal(
        event_type,
        %{"type" => "event_callback", "event" => %{"type" => payload_event_type} = event} =
          payload
      )
      when event_type == payload_event_type and
             event_type in [
               "channel_created",
               "channel_rename",
               "channel_archive",
               "channel_unarchive",
               "member_joined_channel",
               "member_left_channel",
               "file_created",
               "file_shared",
               "file_public",
               "file_deleted",
               "file_change"
             ] do
    {:ok, lifecycle_signal(payload, event)}
  end

  def normalize_signal(event, _payload) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event,
       details: %{event: event}
     )}
  end

  def normalize_event(%{"type" => "event_callback", "event" => %{"type" => type}} = payload) do
    normalize_signal(type, payload)
  end

  def normalize_event(%{"type" => type}) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event,
       details: %{type: type}
     )}
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event
     )}
  end

  defp maybe_put_normalized_signal(%WebhookDelivery{} = delivery) do
    case normalize_signal(delivery) do
      {:ok, signal} -> WebhookDelivery.put_signal(delivery, signal)
      {:error, _reason} -> delivery
    end
  end

  defp delivery_metadata(%WebhookDelivery{} = delivery) do
    Data.compact(%{
      provider: delivery.provider,
      event: delivery.event,
      id: delivery.delivery_id,
      duplicate?: delivery.duplicate?,
      received_at: delivery.received_at
    })
  end

  defp reject_message_subtype(event) do
    case Data.get(event, "subtype") do
      nil ->
        :ok

      "" ->
        :ok

      subtype ->
        {:error,
         Error.provider("Unsupported Slack message subtype",
           provider: :slack,
           reason: :unsupported_message_subtype,
           details: %{subtype: subtype}
         )}
    end
  end

  defp normalize_message_signal(
         %{"type" => "event_callback", "event" => %{"type" => "message"} = event} = payload,
         channel_types
       ) do
    with :ok <- reject_message_subtype(event),
         :ok <- require_message_channel_type(event, channel_types) do
      {:ok, message_signal(payload, event)}
    end
  end

  defp normalize_message_signal(_payload, _channel_types) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event
     )}
  end

  defp normalize_thread_reply_signal(
         %{"type" => "event_callback", "event" => %{"type" => "message"} = event} = payload
       ) do
    with :ok <- reject_message_subtype(event),
         :ok <- require_message_channel_type(event, [nil, "channel", "group", "im", "mpim"]),
         :ok <- require_thread_reply(event) do
      {:ok, message_signal(payload, event)}
    end
  end

  defp normalize_thread_reply_signal(_payload) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event
     )}
  end

  defp message_signal(payload, event) do
    signal =
      Data.compact(%{
        team_id: Data.get(payload, "team_id"),
        event_id: Data.get(payload, "event_id"),
        channel: Data.get(event, "channel"),
        channel_type: Data.get(event, "channel_type"),
        user: Data.get(event, "user"),
        text: Data.get(event, "text"),
        ts: Data.get(event, "ts"),
        thread_ts: Data.get(event, "thread_ts"),
        event_ts: Data.get(event, "event_ts")
      })

    case Data.get(event, "channel_type") do
      channel_type when channel_type in ["im", "mpim"] ->
        Map.merge(signal, direct_message_metadata(event))

      _other ->
        signal
    end
  end

  defp require_thread_reply(event) do
    thread_ts = Data.get(event, "thread_ts")
    ts = Data.get(event, "ts")

    cond do
      thread_ts in [nil, ""] ->
        {:error,
         Error.provider("Slack message is not a thread reply",
           provider: :slack,
           reason: :not_thread_reply
         )}

      thread_ts == ts ->
        {:error,
         Error.provider("Slack message is a thread root",
           provider: :slack,
           reason: :thread_root_message
         )}

      true ->
        :ok
    end
  end

  defp direct_message_metadata(event) do
    Data.compact(%{
      user_team: Data.get(event, "user_team"),
      source_team: Data.get(event, "source_team"),
      sender: sender_metadata(event),
      conversation: conversation_metadata(event)
    })
  end

  defp sender_metadata(event) do
    Data.compact(%{
      id: Data.get(event, "user"),
      team_id: Data.get(event, "user_team") || Data.get(event, "source_team")
    })
  end

  defp conversation_metadata(event) do
    Data.compact(%{
      id: Data.get(event, "channel"),
      type: Data.get(event, "channel_type")
    })
  end

  defp reaction_signal(payload, event) do
    item = reaction_item(event)

    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      user: Data.get(event, "user"),
      reaction: Data.get(event, "reaction"),
      item_user: Data.get(event, "item_user"),
      item: item,
      item_type: Data.get(item, "type"),
      channel: Data.get(item, "channel"),
      ts: Data.get(item, "ts"),
      file: Data.get(item, "file"),
      file_comment: Data.get(item, "file_comment"),
      event_ts: Data.get(event, "event_ts"),
      actor: reaction_actor(payload, event),
      item_owner: reaction_item_owner(payload, event)
    })
  end

  defp reaction_item(event) do
    case Data.get(event, "item") do
      item when is_map(item) -> Data.compact(item)
      _other -> %{}
    end
  end

  defp reaction_actor(payload, event) do
    Data.compact(%{
      id: Data.get(event, "user"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp reaction_item_owner(payload, event) do
    Data.compact(%{
      id: Data.get(event, "item_user"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp lifecycle_signal(payload, %{"type" => event_type} = event)
       when event_type in [
              "member_joined_channel",
              "member_left_channel"
            ] do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      channel_id: channel_id(event),
      channel: Data.get(event, "channel"),
      channel_type: Data.get(event, "channel_type"),
      user: Data.get(event, "user"),
      inviter: Data.get(event, "inviter"),
      event_ts: Data.get(event, "event_ts"),
      actor: channel_actor(payload, event),
      inviter_user: channel_inviter(payload, event)
    })
  end

  defp lifecycle_signal(payload, %{"type" => event_type} = event)
       when event_type in [
              "channel_created",
              "channel_rename",
              "channel_archive",
              "channel_unarchive"
            ] do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      channel_id: channel_id(event),
      channel: channel_metadata(event),
      user: Data.get(event, "user"),
      event_ts: Data.get(event, "event_ts"),
      actor: channel_actor(payload, event)
    })
  end

  defp lifecycle_signal(payload, event), do: file_signal(payload, event)

  defp channel_id(event) do
    case Data.get(event, "channel") do
      channel_id when is_binary(channel_id) -> channel_id
      channel when is_map(channel) -> Data.get(channel, "id")
      _other -> nil
    end
  end

  defp channel_metadata(event) do
    case Data.get(event, "channel") do
      channel when is_map(channel) -> Data.compact(channel)
      _other -> nil
    end
  end

  defp channel_actor(payload, event) do
    channel = channel_metadata(event) || %{}

    Data.compact(%{
      id: Data.get(event, "user") || Data.get(channel, "creator"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp channel_inviter(payload, event) do
    case Data.get(event, "inviter") do
      inviter when is_binary(inviter) and inviter != "" ->
        Data.compact(%{
          id: inviter,
          team_id: Data.get(payload, "team_id")
        })

      _other ->
        nil
    end
  end

  defp file_signal(payload, event) do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      file_id: Data.get(event, "file_id"),
      file: file_metadata(event),
      user_id: Data.get(event, "user_id"),
      channel_id: Data.get(event, "channel_id"),
      event_ts: Data.get(event, "event_ts"),
      actor: file_actor(payload, event)
    })
  end

  defp file_metadata(event) do
    case Data.get(event, "file") do
      file when is_map(file) -> Data.compact(file)
      _other -> nil
    end
  end

  defp file_actor(payload, event) do
    Data.compact(%{
      id: Data.get(event, "user_id"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp require_message_channel_type(event, channel_types) do
    if Data.get(event, "channel_type") in channel_types do
      :ok
    else
      {:error,
       Error.provider("Unsupported Slack message channel type",
         provider: :slack,
         reason: :unsupported_channel_type,
         details: %{channel_type: Data.get(event, "channel_type")}
       )}
    end
  end

  defp parse_timestamp(nil) do
    {:error, Error.auth("Slack request timestamp is required", reason: :missing_timestamp)}
  end

  defp parse_timestamp("") do
    {:error, Error.auth("Slack request timestamp is required", reason: :missing_timestamp)}
  end

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {value, ""} ->
        {:ok, value}

      _other ->
        {:error, Error.auth("Slack request timestamp is invalid", reason: :invalid_timestamp)}
    end
  end

  defp reject_replay(timestamp, now) do
    if abs(now - timestamp) <= @max_skew_seconds do
      :ok
    else
      {:error, Error.auth("Slack request timestamp is stale", reason: :stale_timestamp)}
    end
  end

  defp signature_base(body, timestamp), do: {:ok, "v0:#{timestamp}:#{body}"}

  defp decode_body(body) do
    CoreWebhook.decode_json(body,
      provider: :slack,
      message: "Slack request body is invalid JSON",
      reason: :invalid_payload
    )
  end

  defp header(headers, key) do
    CoreWebhook.header(headers, key)
  end
end
