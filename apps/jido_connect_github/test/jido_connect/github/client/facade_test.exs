defmodule Jido.Connect.GitHub.Client.FacadeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.GitHub.Client

  test "compatibility facade keeps the original public client surface" do
    assert_exported(Client, :list_issues, 3)
    assert_exported(Client, :list_repositories, 2)
    assert_exported(Client, :get_pull_request, 3)
    assert_exported(Client, :dispatch_workflow, 4)
    assert_exported(Client, :upload_release_asset, 3)
  end

  test "API-area modules expose focused client boundaries" do
    assert_exported(Client.Repositories, :get_repository, 3)
    assert_exported(Client.Contents, :read_file, 4)
    assert_exported(Client.Issues, :create_issue, 3)
    assert_exported(Client.PullRequests, :merge_pull_request, 4)
    assert_exported(Client.Actions, :list_workflow_runs, 2)
    assert_exported(Client.Releases, :create_release, 3)
    assert_exported(Client.Search, :search_repositories, 2)
    assert_exported(Client.Identity, :fetch_authenticated_user, 1)
    assert_exported(Client.Installations, :fetch_installation, 2)
  end

  defp assert_exported(module, function, arity) do
    assert {:module, ^module} = Code.ensure_loaded(module)
    assert function_exported?(module, function, arity)
  end
end
