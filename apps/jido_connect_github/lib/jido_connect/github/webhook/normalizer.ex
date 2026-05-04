defmodule Jido.Connect.GitHub.Webhook.Normalizer do
  @moduledoc false

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  @issue_actions ~w(opened edited closed reopened assigned labeled unlabeled)
  @issue_comment_actions ~w(created edited deleted)
  @pull_request_actions ~w(opened synchronize synchronized reopened closed ready_for_review converted_to_draft)
  @pull_request_review_actions ~w(submitted edited dismissed)
  @pull_request_review_comment_actions ~w(created edited deleted)
  @release_actions ~w(published edited unpublished deleted prereleased released)
  @workflow_run_actions ~w(requested in_progress completed)
  @workflow_run_failure_conclusions ~w(failure startup_failure timed_out action_required cancelled)

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

  def normalize_signal("pull_request", payload) when is_map(payload) do
    action = Data.get(payload, "action")

    if action in @pull_request_actions do
      normalize_pull_request_signal(action, payload)
    else
      {:error,
       Error.provider("Unsupported GitHub pull request webhook action",
         provider: :github,
         reason: :unsupported_pull_request_action,
         details: %{action: action}
       )}
    end
  end

  def normalize_signal("pull_request_review", payload) when is_map(payload) do
    action = Data.get(payload, "action")

    if action in @pull_request_review_actions do
      normalize_pull_request_review_signal(action, payload)
    else
      {:error,
       Error.provider("Unsupported GitHub pull request review webhook action",
         provider: :github,
         reason: :unsupported_pull_request_review_action,
         details: %{action: action}
       )}
    end
  end

  def normalize_signal("pull_request_review_comment", payload) when is_map(payload) do
    action = Data.get(payload, "action")

    if action in @pull_request_review_comment_actions do
      normalize_pull_request_review_comment_signal(action, payload)
    else
      {:error,
       Error.provider("Unsupported GitHub pull request review comment webhook action",
         provider: :github,
         reason: :unsupported_pull_request_review_comment_action,
         details: %{action: action}
       )}
    end
  end

  def normalize_signal("release", payload) when is_map(payload) do
    action = Data.get(payload, "action")

    if action in @release_actions do
      normalize_release_signal(action, payload)
    else
      {:error,
       Error.provider("Unsupported GitHub release webhook action",
         provider: :github,
         reason: :unsupported_release_action,
         details: %{action: action}
       )}
    end
  end

  def normalize_signal("workflow_run", payload) when is_map(payload) do
    action = Data.get(payload, "action")

    if action in @workflow_run_actions do
      normalize_workflow_run_signal(action, payload)
    else
      {:error,
       Error.provider("Unsupported GitHub workflow run webhook action",
         provider: :github,
         reason: :unsupported_workflow_run_action,
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

  defp normalize_pull_request_signal(action, payload) do
    pull_request = Data.get(payload, "pull_request") || %{}
    repo = Data.get(payload, "repository") || %{}
    sender = Data.get(payload, "sender") || %{}

    {:ok,
     Data.compact(%{
       action: pull_request_action(action, pull_request),
       github_action: action,
       repo: Data.get(repo, "full_name"),
       pull_request_number: Data.get(pull_request, "number"),
       title: Data.get(pull_request, "title"),
       url: Data.get(pull_request, "html_url") || Data.get(pull_request, "url"),
       state: Data.get(pull_request, "state"),
       draft?: Data.get(pull_request, "draft"),
       merged?: pull_request_merged?(pull_request),
       repository: normalize_repository(repo),
       pull_request: normalize_pull_request(pull_request),
       sender: normalize_actor(sender),
       changes: normalize_changes(Data.get(payload, "changes"))
     })}
  end

  defp normalize_pull_request_review_signal(action, payload) do
    pull_request = Data.get(payload, "pull_request") || %{}
    review = Data.get(payload, "review") || %{}
    repo = Data.get(payload, "repository") || %{}
    sender = Data.get(payload, "sender") || %{}

    {:ok,
     Data.compact(%{
       action: action,
       repo: Data.get(repo, "full_name"),
       pull_request_number: Data.get(pull_request, "number"),
       review_id: Data.get(review, "id"),
       review_state: Data.get(review, "state"),
       title: Data.get(pull_request, "title"),
       url: Data.get(review, "html_url") || Data.get(pull_request, "html_url"),
       repository: normalize_repository(repo),
       pull_request: normalize_pull_request(pull_request),
       review: normalize_pull_request_review(review),
       sender: normalize_actor(sender),
       changes: normalize_changes(Data.get(payload, "changes"))
     })}
  end

  defp normalize_pull_request_review_comment_signal(action, payload) do
    pull_request = Data.get(payload, "pull_request") || %{}
    comment = Data.get(payload, "comment") || %{}
    repo = Data.get(payload, "repository") || %{}
    sender = Data.get(payload, "sender") || %{}

    {:ok,
     Data.compact(%{
       action: action,
       repo: Data.get(repo, "full_name"),
       pull_request_number: Data.get(pull_request, "number"),
       comment_id: Data.get(comment, "id"),
       title: Data.get(pull_request, "title"),
       url: Data.get(comment, "html_url") || Data.get(comment, "url"),
       repository: normalize_repository(repo),
       pull_request: normalize_pull_request(pull_request),
       comment: normalize_pull_request_review_comment(comment),
       sender: normalize_actor(sender),
       changes: normalize_changes(Data.get(payload, "changes"))
     })}
  end

  defp normalize_release_signal(action, payload) do
    release = Data.get(payload, "release") || %{}
    repo = Data.get(payload, "repository") || %{}
    sender = Data.get(payload, "sender") || %{}

    {:ok,
     Data.compact(%{
       action: action,
       repo: Data.get(repo, "full_name"),
       release_id: Data.get(release, "id"),
       tag_name: Data.get(release, "tag_name"),
       name: Data.get(release, "name"),
       url: Data.get(release, "html_url") || Data.get(release, "url"),
       draft?: Data.get(release, "draft"),
       prerelease?: Data.get(release, "prerelease"),
       target_commitish: Data.get(release, "target_commitish"),
       published_at: Data.get(release, "published_at"),
       repository: normalize_repository(repo),
       release: normalize_release(release),
       sender: normalize_actor(sender),
       changes: normalize_changes(Data.get(payload, "changes"))
     })}
  end

  defp normalize_workflow_run_signal(action, payload) do
    workflow_run = Data.get(payload, "workflow_run") || %{}
    repo = Data.get(payload, "repository") || %{}
    sender = Data.get(payload, "sender") || %{}
    conclusion = Data.get(workflow_run, "conclusion")

    {:ok,
     Data.compact(%{
       action: action,
       repo: Data.get(repo, "full_name"),
       workflow_run_id: Data.get(workflow_run, "id"),
       workflow_run_number: Data.get(workflow_run, "run_number"),
       workflow_name: Data.get(workflow_run, "name"),
       status: Data.get(workflow_run, "status"),
       conclusion: conclusion,
       ci_status: normalize_ci_status(Data.get(workflow_run, "status"), conclusion),
       failure?: workflow_run_failure?(conclusion),
       failure_kind: workflow_run_failure_kind(conclusion),
       branch: Data.get(workflow_run, "head_branch"),
       sha: Data.get(workflow_run, "head_sha"),
       workflow_id: Data.get(workflow_run, "workflow_id"),
       run_attempt: Data.get(workflow_run, "run_attempt"),
       run_started_at: Data.get(workflow_run, "run_started_at"),
       url: Data.get(workflow_run, "html_url") || Data.get(workflow_run, "url"),
       repository: normalize_repository(repo),
       workflow_run: normalize_workflow_run(workflow_run),
       sender: normalize_actor(sender)
     })}
  end

  def maybe_put_normalized_signal(%WebhookDelivery{} = delivery) do
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

  defp normalize_pull_request(pull_request) when is_map(pull_request) do
    Data.compact(%{
      id: Data.get(pull_request, "id"),
      node_id: Data.get(pull_request, "node_id"),
      number: Data.get(pull_request, "number"),
      title: Data.get(pull_request, "title"),
      body: Data.get(pull_request, "body"),
      state: Data.get(pull_request, "state"),
      draft?: Data.get(pull_request, "draft"),
      merged?: pull_request_merged?(pull_request),
      mergeable?: Data.get(pull_request, "mergeable"),
      rebaseable?: Data.get(pull_request, "rebaseable"),
      url: Data.get(pull_request, "html_url") || Data.get(pull_request, "url"),
      api_url: Data.get(pull_request, "url"),
      diff_url: Data.get(pull_request, "diff_url"),
      patch_url: Data.get(pull_request, "patch_url"),
      created_at: Data.get(pull_request, "created_at"),
      updated_at: Data.get(pull_request, "updated_at"),
      closed_at: Data.get(pull_request, "closed_at"),
      merged_at: Data.get(pull_request, "merged_at"),
      author: normalize_actor(Data.get(pull_request, "user") || %{}),
      assignees: normalize_actors(Data.get(pull_request, "assignees", [])),
      labels: normalize_labels(Data.get(pull_request, "labels", [])),
      head: normalize_pull_request_branch(Data.get(pull_request, "head")),
      base: normalize_pull_request_branch(Data.get(pull_request, "base"))
    })
  end

  defp normalize_pull_request(_pull_request), do: %{}

  defp normalize_pull_request_review(review) when is_map(review) do
    Data.compact(%{
      id: Data.get(review, "id"),
      node_id: Data.get(review, "node_id"),
      body: Data.get(review, "body"),
      state: Data.get(review, "state"),
      commit_id: Data.get(review, "commit_id"),
      submitted_at: Data.get(review, "submitted_at"),
      url: Data.get(review, "html_url") || Data.get(review, "url"),
      api_url: Data.get(review, "url"),
      pull_request_url: Data.get(review, "pull_request_url"),
      author: normalize_actor(Data.get(review, "user") || %{})
    })
  end

  defp normalize_pull_request_review(_review), do: %{}

  defp normalize_pull_request_review_comment(comment) when is_map(comment) do
    Data.compact(%{
      id: Data.get(comment, "id"),
      node_id: Data.get(comment, "node_id"),
      body: Data.get(comment, "body"),
      diff_hunk: Data.get(comment, "diff_hunk"),
      path: Data.get(comment, "path"),
      position: Data.get(comment, "position"),
      original_position: Data.get(comment, "original_position"),
      line: Data.get(comment, "line"),
      original_line: Data.get(comment, "original_line"),
      side: Data.get(comment, "side"),
      start_line: Data.get(comment, "start_line"),
      original_start_line: Data.get(comment, "original_start_line"),
      start_side: Data.get(comment, "start_side"),
      commit_id: Data.get(comment, "commit_id"),
      original_commit_id: Data.get(comment, "original_commit_id"),
      in_reply_to_id: Data.get(comment, "in_reply_to_id"),
      pull_request_review_id: Data.get(comment, "pull_request_review_id"),
      url: Data.get(comment, "html_url") || Data.get(comment, "url"),
      api_url: Data.get(comment, "url"),
      pull_request_url: Data.get(comment, "pull_request_url"),
      created_at: Data.get(comment, "created_at"),
      updated_at: Data.get(comment, "updated_at"),
      author: normalize_actor(Data.get(comment, "user") || %{})
    })
  end

  defp normalize_pull_request_review_comment(_comment), do: %{}

  defp normalize_release(release) when is_map(release) do
    Data.compact(%{
      id: Data.get(release, "id"),
      node_id: Data.get(release, "node_id"),
      tag_name: Data.get(release, "tag_name"),
      name: Data.get(release, "name"),
      body: Data.get(release, "body"),
      draft?: Data.get(release, "draft"),
      prerelease?: Data.get(release, "prerelease"),
      target_commitish: Data.get(release, "target_commitish"),
      url: Data.get(release, "html_url") || Data.get(release, "url"),
      api_url: Data.get(release, "url"),
      upload_url: Data.get(release, "upload_url"),
      tarball_url: Data.get(release, "tarball_url"),
      zipball_url: Data.get(release, "zipball_url"),
      created_at: Data.get(release, "created_at"),
      published_at: Data.get(release, "published_at"),
      author: normalize_actor(Data.get(release, "author") || %{})
    })
  end

  defp normalize_release(_release), do: %{}

  defp normalize_workflow_run(workflow_run) when is_map(workflow_run) do
    Data.compact(%{
      id: Data.get(workflow_run, "id"),
      node_id: Data.get(workflow_run, "node_id"),
      name: Data.get(workflow_run, "name"),
      number: Data.get(workflow_run, "run_number"),
      run_attempt: Data.get(workflow_run, "run_attempt"),
      status: Data.get(workflow_run, "status"),
      conclusion: Data.get(workflow_run, "conclusion"),
      ci_status:
        normalize_ci_status(
          Data.get(workflow_run, "status"),
          Data.get(workflow_run, "conclusion")
        ),
      event: Data.get(workflow_run, "event"),
      branch: Data.get(workflow_run, "head_branch"),
      sha: Data.get(workflow_run, "head_sha"),
      workflow_id: Data.get(workflow_run, "workflow_id"),
      check_suite_id: Data.get(workflow_run, "check_suite_id"),
      check_suite_node_id: Data.get(workflow_run, "check_suite_node_id"),
      url: Data.get(workflow_run, "html_url") || Data.get(workflow_run, "url"),
      jobs_url: Data.get(workflow_run, "jobs_url"),
      logs_url: Data.get(workflow_run, "logs_url"),
      created_at: Data.get(workflow_run, "created_at"),
      updated_at: Data.get(workflow_run, "updated_at"),
      run_started_at: Data.get(workflow_run, "run_started_at"),
      actor: normalize_actor(Data.get(workflow_run, "actor") || %{}),
      triggering_actor: normalize_actor(Data.get(workflow_run, "triggering_actor") || %{}),
      head_commit: normalize_commit(Data.get(workflow_run, "head_commit"))
    })
  end

  defp normalize_workflow_run(_workflow_run), do: %{}

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

  defp normalize_pull_request_branch(branch) when is_map(branch) do
    Data.compact(%{
      label: Data.get(branch, "label"),
      ref: Data.get(branch, "ref"),
      sha: Data.get(branch, "sha"),
      user: normalize_actor(Data.get(branch, "user") || %{}),
      repo: normalize_repository(Data.get(branch, "repo") || %{})
    })
  end

  defp normalize_pull_request_branch(_branch), do: nil

  defp pull_request_action("closed", pull_request) do
    if pull_request_merged?(pull_request), do: "merged", else: "closed"
  end

  defp pull_request_action(action, _pull_request), do: action

  defp pull_request_merged?(pull_request) when is_map(pull_request) do
    Data.get(pull_request, "merged") == true or not is_nil(Data.get(pull_request, "merged_at"))
  end

  defp pull_request_merged?(_pull_request), do: false

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

  defp normalize_ci_status(_status, conclusion) when conclusion in ["success", "failure"] do
    conclusion
  end

  defp normalize_ci_status(_status, conclusion)
       when conclusion in [
              "cancelled",
              "skipped",
              "startup_failure",
              "timed_out",
              "action_required",
              "neutral"
            ] do
    conclusion
  end

  defp normalize_ci_status(status, _conclusion)
       when status in ["queued", "waiting", "requested"] do
    "queued"
  end

  defp normalize_ci_status(status, _conclusion) when status in ["in_progress", "pending"] do
    "in_progress"
  end

  defp normalize_ci_status("completed", _conclusion), do: "unknown"
  defp normalize_ci_status(status, _conclusion) when is_binary(status), do: status
  defp normalize_ci_status(_status, _conclusion), do: "unknown"

  defp workflow_run_failure?(conclusion), do: conclusion in @workflow_run_failure_conclusions

  defp workflow_run_failure_kind(conclusion) when conclusion in @workflow_run_failure_conclusions,
    do: conclusion

  defp workflow_run_failure_kind(_conclusion), do: nil

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
end
