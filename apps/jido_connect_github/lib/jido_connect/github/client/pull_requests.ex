defmodule Jido.Connect.GitHub.Client.PullRequests do
  @moduledoc "GitHub pull request API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate list_pull_requests(params, access_token), to: Rest
  defdelegate get_pull_request(repo, pull_number, access_token), to: Rest
  defdelegate list_pull_request_files(params, access_token), to: Rest
  defdelegate create_pull_request(repo, attrs, access_token), to: Rest
  defdelegate update_pull_request(repo, pull_number, attrs, access_token), to: Rest
  defdelegate request_pull_request_reviewers(repo, pull_number, attrs, access_token), to: Rest
  defdelegate create_pull_request_review_comment(repo, pull_number, attrs, access_token), to: Rest
  defdelegate merge_pull_request(repo, pull_number, attrs, access_token), to: Rest
  defdelegate list_updated_pull_requests(repo, checkpoint, access_token), to: Rest
end
