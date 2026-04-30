defmodule Jido.Connect.GitHub.Client.Repositories do
  @moduledoc "GitHub repository, branch, commit, and compare API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate list_repositories(params, access_token), to: Rest
  defdelegate get_repository(owner, name, access_token), to: Rest
  defdelegate list_branches(params, access_token), to: Rest
  defdelegate create_branch(repo, attrs, access_token), to: Rest
  defdelegate list_commits(params, access_token), to: Rest
  defdelegate compare_refs(params, access_token), to: Rest
end
