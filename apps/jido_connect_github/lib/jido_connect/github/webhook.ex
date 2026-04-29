defmodule Jido.Connect.GitHub.Webhook do
  @moduledoc """
  Pure helpers for GitHub webhook verification and event normalization.
  """

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Webhook, as: CoreWebhook

  @issue_actions ~w(opened edited closed reopened assigned labeled unlabeled)
  @issue_comment_actions ~w(created edited deleted)

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

  def normalize_signal("issues", payload) when is_map(payload) do
    action = Data.get(payload, "action")

    if action in @issue_actions do
      normalize_issue_signal(action, payload)
    else
      {:error,
       Error.provider("Unsupported GitHub issue webhook action",
         provider: :github,
         reason: :unsupported_issue_action,
         details: %{action: action}
       )}
    end
  end

  def normalize_signal("issue_comment", payload) when is_map(payload) do
    action = Data.get(payload, "action")

    if action in @issue_comment_actions do
      normalize_issue_comment_signal(action, payload)
    else
      {:error,
       Error.provider("Unsupported GitHub issue comment webhook action",
         provider: :github,
         reason: :unsupported_issue_comment_action,
         details: %{action: action}
       )}
    end
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

  defp normalize_issue_signal(action, payload) do
    issue = Data.get(payload, "issue") || %{}
    repo = Data.get(payload, "repository") || %{}
    sender = Data.get(payload, "sender") || %{}

    {:ok,
     Data.compact(%{
       action: action,
       repo: Data.get(repo, "full_name"),
       issue_number: Data.get(issue, "number"),
       title: Data.get(issue, "title"),
       url: Data.get(issue, "html_url") || Data.get(issue, "url"),
       repository: normalize_repository(repo),
       issue: normalize_issue(issue),
       sender: normalize_actor(sender),
       changes: normalize_changes(Data.get(payload, "changes")),
       assignee: normalize_optional_actor(Data.get(payload, "assignee")),
       label: normalize_label(Data.get(payload, "label"))
     })}
  end

  defp normalize_issue_comment_signal(action, payload) do
    issue = Data.get(payload, "issue") || %{}
    comment = Data.get(payload, "comment") || %{}
    repo = Data.get(payload, "repository") || %{}
    sender = Data.get(payload, "sender") || %{}
    pull_request? = pull_request_issue?(issue)

    {:ok,
     Data.compact(%{
       action: action,
       repo: Data.get(repo, "full_name"),
       issue_number: Data.get(issue, "number"),
       title: Data.get(issue, "title"),
       url: Data.get(comment, "html_url") || Data.get(comment, "url"),
       comment_id: Data.get(comment, "id"),
       comment_target: comment_target(pull_request?),
       pull_request?: pull_request?,
       repository: normalize_repository(repo),
       issue: normalize_issue(issue),
       comment: normalize_issue_comment(comment),
       sender: normalize_actor(sender),
       changes: normalize_changes(Data.get(payload, "changes"))
     })}
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

  defp normalize_issue(issue) when is_map(issue) do
    Data.compact(%{
      id: Data.get(issue, "id"),
      node_id: Data.get(issue, "node_id"),
      number: Data.get(issue, "number"),
      title: Data.get(issue, "title"),
      body: Data.get(issue, "body"),
      state: Data.get(issue, "state"),
      state_reason: Data.get(issue, "state_reason"),
      locked?: Data.get(issue, "locked"),
      comments: Data.get(issue, "comments"),
      url: Data.get(issue, "html_url") || Data.get(issue, "url"),
      api_url: Data.get(issue, "url"),
      created_at: Data.get(issue, "created_at"),
      updated_at: Data.get(issue, "updated_at"),
      closed_at: Data.get(issue, "closed_at"),
      author: normalize_actor(Data.get(issue, "user") || %{}),
      assignees: normalize_actors(Data.get(issue, "assignees", [])),
      labels: normalize_labels(Data.get(issue, "labels", [])),
      pull_request?: pull_request_issue?(issue),
      pull_request: normalize_pull_request_ref(Data.get(issue, "pull_request"))
    })
  end

  defp normalize_issue(_issue), do: %{}

  defp normalize_issue_comment(comment) when is_map(comment) do
    Data.compact(%{
      id: Data.get(comment, "id"),
      node_id: Data.get(comment, "node_id"),
      body: Data.get(comment, "body"),
      url: Data.get(comment, "html_url") || Data.get(comment, "url"),
      api_url: Data.get(comment, "url"),
      issue_url: Data.get(comment, "issue_url"),
      created_at: Data.get(comment, "created_at"),
      updated_at: Data.get(comment, "updated_at"),
      author: normalize_actor(Data.get(comment, "user") || %{})
    })
  end

  defp normalize_issue_comment(_comment), do: %{}

  defp pull_request_issue?(issue) when is_map(issue), do: is_map(Data.get(issue, "pull_request"))
  defp pull_request_issue?(_issue), do: false

  defp comment_target(true), do: "pull_request"
  defp comment_target(false), do: "issue"

  defp normalize_pull_request_ref(pull_request) when is_map(pull_request) do
    Data.compact(%{
      url: Data.get(pull_request, "html_url") || Data.get(pull_request, "url"),
      api_url: Data.get(pull_request, "url"),
      diff_url: Data.get(pull_request, "diff_url"),
      patch_url: Data.get(pull_request, "patch_url")
    })
  end

  defp normalize_pull_request_ref(_pull_request), do: nil

  defp normalize_actors(actors) when is_list(actors), do: Enum.map(actors, &normalize_actor/1)
  defp normalize_actors(_actors), do: []

  defp normalize_optional_actor(actor) when is_map(actor), do: normalize_actor(actor)
  defp normalize_optional_actor(_actor), do: nil

  defp normalize_labels(labels) when is_list(labels), do: Enum.map(labels, &normalize_label/1)
  defp normalize_labels(_labels), do: []

  defp normalize_label(label) when is_map(label) do
    Data.compact(%{
      id: Data.get(label, "id"),
      node_id: Data.get(label, "node_id"),
      name: Data.get(label, "name"),
      description: Data.get(label, "description"),
      color: Data.get(label, "color"),
      default?: Data.get(label, "default"),
      url: Data.get(label, "url")
    })
  end

  defp normalize_label(_label), do: nil

  defp normalize_changes(changes) when is_map(changes) do
    changes
    |> Enum.map(fn {field, value} -> {field, normalize_change(value)} end)
    |> Map.new()
  end

  defp normalize_changes(_changes), do: nil

  defp normalize_change(change) when is_map(change) do
    Data.compact(%{
      from: Data.get(change, "from")
    })
  end

  defp normalize_change(change), do: change

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
end
