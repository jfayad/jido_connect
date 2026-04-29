defmodule Jido.Connect.GitHub.Webhook do
  @moduledoc """
  Pure helpers for GitHub webhook verification and event normalization.
  """

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Webhook, as: CoreWebhook

  def parse_headers(headers) when is_map(headers) do
    %{
      delivery_id: header(headers, "x-github-delivery"),
      event: header(headers, "x-github-event"),
      signature: header(headers, "x-hub-signature-256")
    }
  end

  def verify_signature(body, signature, secret)

  def verify_signature(_body, _signature, nil),
    do: {:error, Error.auth("GitHub webhook secret is required", reason: :missing_secret)}

  def verify_signature(_body, _signature, ""),
    do: {:error, Error.auth("GitHub webhook secret is required", reason: :missing_secret)}

  def verify_signature(_body, nil, _secret),
    do: {:error, Error.auth("GitHub webhook signature is required", reason: :missing_signature)}

  def verify_signature(body, "sha256=" <> expected, secret)
      when is_binary(body) and is_binary(secret) do
    CoreWebhook.verify_hmac_sha256(body, "sha256=" <> expected, secret,
      prefix: "sha256=",
      invalid_signature_message: "GitHub webhook signature is invalid",
      invalid_signature_reason: :invalid_signature
    )
  end

  def verify_signature(_body, _signature, _secret),
    do: {:error, Error.auth("GitHub webhook signature is invalid", reason: :invalid_signature)}

  def verify_request(body, headers, secret) do
    with {:ok, delivery} <- verify_delivery(body, headers, secret) do
      {:ok,
       %{
         delivery_id: delivery.delivery_id,
         event: delivery.event,
         signature: delivery.metadata.signature,
         payload: delivery.payload
       }}
    end
  end

  def verify_delivery(body, headers, secret, opts \\ []) do
    parsed = parse_headers(headers)

    with :ok <- verify_signature(body, parsed.signature, secret),
         {:ok, payload} <- decode_body(body),
         {:ok, delivery} <-
           WebhookDelivery.verified(:github, %{
             delivery_id: parsed.delivery_id,
             event: parsed.event,
             headers: headers,
             payload: payload,
             duplicate?:
               duplicate?(parsed.delivery_id, Keyword.get(opts, :seen_delivery_ids, [])),
             metadata: %{signature: parsed.signature}
           }) do
      {:ok, maybe_put_normalized_signal(delivery)}
    end
  end

  def normalize_signal(%WebhookDelivery{event: event, payload: payload} = delivery) do
    with {:ok, signal} <- normalize_signal(event, payload) do
      {:ok, Map.put(signal, :delivery, delivery_metadata(delivery))}
    end
  end

  def normalize_signal("push", payload) when is_map(payload) do
    repository = Data.get(payload, "repository") || %{}
    pusher = Data.get(payload, "pusher") || %{}

    {:ok,
     %{
       repository: normalize_repository(repository),
       ref: normalize_ref(Data.get(payload, "ref")),
       before: Data.get(payload, "before"),
       after: Data.get(payload, "after"),
       compare_url: Data.get(payload, "compare"),
       commits: normalize_commits(Data.get(payload, "commits", [])),
       head_commit: normalize_commit(Data.get(payload, "head_commit")),
       pusher: normalize_actor(pusher),
       created?: Data.get(payload, "created"),
       deleted?: Data.get(payload, "deleted"),
       forced?: Data.get(payload, "forced")
     }}
  end

  def normalize_signal("issues", %{"action" => "opened"} = payload) do
    issue = Data.get(payload, "issue") || %{}
    repo = Data.get(payload, "repository") || %{}

    {:ok,
     %{
       repo: Data.get(repo, "full_name"),
       issue_number: Data.get(issue, "number"),
       title: Data.get(issue, "title"),
       url: Data.get(issue, "html_url") || Data.get(issue, "url")
     }}
  end

  def normalize_signal("issues", %{action: "opened"} = payload) do
    normalize_signal("issues", stringify_keys(payload))
  end

  def normalize_signal("issues", payload) when is_map(payload) do
    {:error,
     Error.provider("Unsupported GitHub issue webhook action",
       provider: :github,
       reason: :unsupported_issue_action,
       details: %{action: Data.get(payload, "action")}
     )}
  end

  def normalize_signal(event, _payload) do
    {:error,
     Error.provider("Unsupported GitHub webhook event",
       provider: :github,
       reason: :unsupported_event,
       details: %{event: event}
     )}
  end

  def duplicate?(delivery_id, seen_delivery_ids) do
    CoreWebhook.duplicate?(delivery_id, seen_delivery_ids)
  end

  defp maybe_put_normalized_signal(%WebhookDelivery{} = delivery) do
    case normalize_signal(delivery) do
      {:ok, signal} -> WebhookDelivery.put_signal(delivery, signal)
      {:error, _reason} -> delivery
    end
  end

  defp normalize_repository(repository) do
    owner = Data.get(repository, "owner") || %{}

    Data.compact(%{
      id: Data.get(repository, "id"),
      node_id: Data.get(repository, "node_id"),
      name: Data.get(repository, "name"),
      full_name: Data.get(repository, "full_name"),
      owner: normalize_actor(owner),
      private?: Data.get(repository, "private"),
      default_branch: Data.get(repository, "default_branch"),
      url: Data.get(repository, "html_url") || Data.get(repository, "url")
    })
  end

  defp normalize_ref("refs/heads/" <> branch) do
    %{full: "refs/heads/" <> branch, name: branch, type: "branch"}
  end

  defp normalize_ref("refs/tags/" <> tag) do
    %{full: "refs/tags/" <> tag, name: tag, type: "tag"}
  end

  defp normalize_ref(ref) when is_binary(ref) do
    %{full: ref, name: ref, type: "unknown"}
  end

  defp normalize_ref(_ref), do: nil

  defp normalize_commits(commits) when is_list(commits) do
    Enum.map(commits, &normalize_commit/1)
  end

  defp normalize_commits(_commits), do: []

  defp normalize_commit(commit) when is_map(commit) do
    Data.compact(%{
      id: Data.get(commit, "id"),
      tree_id: Data.get(commit, "tree_id"),
      distinct?: Data.get(commit, "distinct"),
      message: Data.get(commit, "message"),
      timestamp: Data.get(commit, "timestamp"),
      url: Data.get(commit, "url"),
      author: normalize_actor(Data.get(commit, "author") || %{}),
      committer: normalize_actor(Data.get(commit, "committer") || %{}),
      added: Data.get(commit, "added", []),
      removed: Data.get(commit, "removed", []),
      modified: Data.get(commit, "modified", [])
    })
  end

  defp normalize_commit(_commit), do: nil

  defp normalize_actor(actor) when is_map(actor) do
    Data.compact(%{
      id: Data.get(actor, "id"),
      node_id: Data.get(actor, "node_id"),
      login: Data.get(actor, "login"),
      name: Data.get(actor, "name"),
      email: Data.get(actor, "email"),
      username: Data.get(actor, "username"),
      url: Data.get(actor, "html_url") || Data.get(actor, "url")
    })
  end

  defp normalize_actor(_actor), do: %{}

  defp delivery_metadata(%WebhookDelivery{} = delivery) do
    %{
      provider: delivery.provider,
      event: delivery.event,
      id: delivery.delivery_id,
      duplicate?: delivery.duplicate?,
      received_at: delivery.received_at
    }
  end

  defp decode_body(body) when is_binary(body) do
    CoreWebhook.decode_json(body,
      provider: :github,
      message: "GitHub webhook body is invalid JSON",
      reason: :invalid_payload
    )
  end

  defp header(headers, key) do
    CoreWebhook.header(headers, key)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
