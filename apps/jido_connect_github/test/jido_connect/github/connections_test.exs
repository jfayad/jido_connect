defmodule Jido.Connect.GitHub.ConnectionsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Connection
  alias Jido.Connect.GitHub.Connections

  test "builds user-level GitHub OAuth connections" do
    assert {:ok, %Connection{} = connection} =
             Connections.user_connection(
               %{"login" => "octocat", "id" => 1, "scope" => "repo read:user"},
               tenant_id: "tenant_1",
               credential_ref: "vault:github:user:octocat"
             )

    assert connection.id == "github-user-octocat"
    assert connection.provider == :github
    assert connection.profile == :user
    assert connection.tenant_id == "tenant_1"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "octocat"
    assert connection.subject == %{github_login: "octocat", github_user_id: "1"}
    assert connection.credential_ref == "vault:github:user:octocat"
    assert connection.scopes == ["repo", "read:user"]
    assert connection.metadata.mode == :github_oauth
  end

  test "builds tenant-owned organization installation connections" do
    installation = %{
      "id" => 42,
      "account" => %{"login" => "acme", "id" => 99, "type" => "Organization"},
      "repository_selection" => "all",
      "permissions" => %{"metadata" => "read", "issues" => "write"}
    }

    assert {:ok, %Connection{} = connection} =
             Connections.installation_connection(installation, tenant_id: "tenant_1")

    assert connection.id == "github-installation-42"
    assert connection.profile == :installation
    assert connection.owner_type == :tenant
    assert connection.owner_id == "tenant_1"

    assert connection.subject == %{
             installation_id: "42",
             account_login: "acme",
             account_id: 99,
             account_type: "Organization"
           }

    assert connection.credential_ref == "github-app:42"
    assert connection.metadata.mode == :github_app
    assert connection.metadata.repository_selection == "all"
    assert connection.scopes == ["issues:read", "issues:write", "metadata:read"]
  end

  test "builds app-user-owned user account installation connections" do
    installation = %{
      id: "77",
      account: %{login: "octocat", type: "User"},
      repository_selection: "selected"
    }

    assert {:ok, %Connection{} = connection} =
             Connections.installation_connection(installation, tenant_id: "tenant_1")

    assert connection.id == "github-installation-77"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "octocat"
    assert connection.subject.account_type == "User"
    assert connection.subject.account_login == "octocat"
    assert connection.metadata.repository_selection == "selected"

    assert connection.scopes == [
             "actions:read",
             "actions:write",
             "metadata:read",
             "issues:read",
             "issues:write"
           ]
  end

  test "lets hosts override installation ownership and ids" do
    assert {:ok, %Connection{} = connection} =
             Connections.user_installation_connection(42,
               id: "conn_custom",
               tenant_id: "tenant_1",
               owner_id: "user_1",
               credential_ref: "vault:github:installation:42",
               scopes: ["metadata:read", "issues:read"],
               metadata: %{source: :test}
             )

    assert connection.id == "conn_custom"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "user_1"
    assert connection.credential_ref == "vault:github:installation:42"
    assert connection.scopes == ["metadata:read", "issues:read"]
    assert connection.metadata.source == :test
  end
end
