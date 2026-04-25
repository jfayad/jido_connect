defmodule Jido.Connect.Slack.Webhook do
  @moduledoc """
  Pure helpers for Slack signed request verification and Events API payloads.
  """

  @max_skew_seconds 300

  def parse_headers(headers) when is_map(headers) do
    %{
      signature: header(headers, "x-slack-signature"),
      timestamp: header(headers, "x-slack-request-timestamp")
    }
  end

  def verify_signature(body, headers, signing_secret, opts \\ [])

  def verify_signature(_body, _headers, nil, _opts), do: {:error, :missing_signing_secret}
  def verify_signature(_body, _headers, "", _opts), do: {:error, :missing_signing_secret}

  def verify_signature(body, headers, signing_secret, opts)
      when is_binary(body) and is_map(headers) and is_binary(signing_secret) do
    parsed = parse_headers(headers)
    now = Keyword.get(opts, :now, System.system_time(:second))

    with {:ok, timestamp} <- parse_timestamp(parsed.timestamp),
         :ok <- reject_replay(timestamp, now),
         {:ok, expected} <- expected_signature(body, timestamp, signing_secret) do
      if secure_compare(expected, parsed.signature || "") do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  def verify_request(body, headers, signing_secret, opts \\ []) do
    with :ok <- verify_signature(body, headers, signing_secret, opts),
         {:ok, payload} <- Jason.decode(body) do
      {:ok, payload}
    end
  end

  def url_verification_challenge(%{"type" => "url_verification", "challenge" => challenge})
      when is_binary(challenge) do
    {:ok, challenge}
  end

  def url_verification_challenge(_payload), do: {:error, :not_url_verification}

  def normalize_event(
        %{"type" => "event_callback", "event" => %{"type" => "app_mention"} = event} = payload
      ) do
    {:ok,
     %{
       team_id: Map.get(payload, "team_id"),
       event_id: Map.get(payload, "event_id"),
       channel: Map.get(event, "channel"),
       user: Map.get(event, "user"),
       text: Map.get(event, "text"),
       ts: Map.get(event, "ts")
     }}
  end

  def normalize_event(%{"type" => type}), do: {:error, {:unsupported_event, type}}
  def normalize_event(_payload), do: {:error, :unsupported_event}

  defp parse_timestamp(nil), do: {:error, :missing_timestamp}
  defp parse_timestamp(""), do: {:error, :missing_timestamp}

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {value, ""} -> {:ok, value}
      _other -> {:error, :invalid_timestamp}
    end
  end

  defp reject_replay(timestamp, now) do
    if abs(now - timestamp) <= @max_skew_seconds do
      :ok
    else
      {:error, :stale_timestamp}
    end
  end

  defp expected_signature(body, timestamp, signing_secret) do
    base = "v0:#{timestamp}:#{body}"

    signature =
      :hmac
      |> :crypto.mac(:sha256, signing_secret, base)
      |> Base.encode16(case: :lower)

    {:ok, "v0=#{signature}"}
  end

  defp header(headers, key) do
    Map.get(headers, key) || Map.get(headers, String.downcase(key)) ||
      Map.get(headers, String.to_atom(key))
  end

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {left_byte, right_byte}, acc ->
      :erlang.bor(acc, :erlang.bxor(left_byte, right_byte))
    end)
    |> Kernel.==(0)
  end

  defp secure_compare(_left, _right), do: false
end
