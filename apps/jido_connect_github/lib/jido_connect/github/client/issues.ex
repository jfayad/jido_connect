defmodule Jido.Connect.GitHub.Client.Issues do
  @moduledoc "GitHub issue and issue-comment API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate list_issues(repo, state, access_token), to: Rest
  defdelegate create_issue(repo, attrs, access_token), to: Rest
  defdelegate update_issue(repo, issue_number, attrs, access_token), to: Rest
  defdelegate add_issue_labels(repo, issue_number, labels, access_token), to: Rest
  defdelegate assign_issue(repo, issue_number, assignees, access_token), to: Rest
  defdelegate create_issue_comment(repo, issue_number, body, access_token), to: Rest
  defdelegate list_issue_comments(params, access_token), to: Rest
  defdelegate close_issue(repo, number, access_token), to: Rest
  defdelegate list_new_issues(repo, checkpoint, access_token), to: Rest
end
