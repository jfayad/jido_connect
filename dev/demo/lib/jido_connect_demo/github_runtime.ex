defmodule Jido.Connect.Demo.GitHubRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Demo.Store
  alias Jido.Connect.GitHub.AppAuth

  def create_manual_connection(attrs) do
    token = Map.get(attrs, "token") || System.get_env("GITHUB_TOKEN")
    owner_id = Map.get(attrs, "owner_id", "local-user")
    tenant_id = Map.get(attrs, "tenant_id", "local")
    credential_ref = "demo:github-manual-#{owner_id}"

    connection =
      Connect.Connection.new!(%{
        id: "github-manual-#{owner_id}",
        provider: :github,
        profile: :user,
        tenant_id: tenant_id,
        owner_type: :user,
        owner_id: owner_id,
        status: if(blank?(token), do: :needs_credentials, else: :connected),
        credential_ref: credential_ref,
        scopes: ["repo", "read:user"],
        metadata: %{mode: :manual_token}
      })

    if not blank?(token), do: Store.put_credential(credential_ref, %{access_token: token})

    Store.put_connection(connection)
  end

  def create_installation_connection(installation_id, attrs \\ %{}) do
    tenant_id = Map.get(attrs, "tenant_id", "local")
    owner_id = Map.get(attrs, "owner_id", "installation-#{installation_id}")

    connection =
      Connect.Connection.new!(%{
        id: "github-installation-#{installation_id}",
        provider: :github,
        profile: :installation,
        tenant_id: tenant_id,
        owner_type: :installation,
        owner_id: owner_id,
        status: :connected,
        credential_ref: "github-app:#{installation_id}",
        scopes: ["metadata:read", "issues:read", "issues:write"],
        metadata: %{mode: :github_app, installation_id: installation_id}
      })

    Store.put_connection(connection)
  end

  def context_and_lease(connection_id, opts \\ []) do
    with {:ok, connection} <- Store.get_connection(connection_id),
         {:ok, lease} <- lease_for(connection, opts) do
      context =
        Connect.Context.new!(%{
          tenant_id: connection.tenant_id,
          actor: %{id: connection.owner_id, type: connection.owner_type},
          connection: connection
        })

      {:ok, context, lease}
    end
  end

  def run_list_issues(connection_id, params, opts \\ []) do
    with {:ok, context, lease} <- context_and_lease(connection_id, opts) do
      Jido.Connect.GitHub.Actions.ListIssues.run(params, %{
        integration_context: context,
        credential_lease: lease
      })
    end
  end

  def run_create_issue(connection_id, params, opts \\ []) do
    with {:ok, context, lease} <- context_and_lease(connection_id, opts) do
      Jido.Connect.GitHub.Actions.CreateIssue.run(params, %{
        integration_context: context,
        credential_lease: lease
      })
    end
  end

  def poll_new_issues(connection_id, params, opts \\ []) do
    with {:ok, context, lease} <- context_and_lease(connection_id, opts),
         {:ok, state, _directives} <-
           Jido.Connect.GitHub.Sensors.NewIssues.init(params, %{
             integration_context: context,
             credential_lease: lease
           }) do
      Jido.Connect.GitHub.Sensors.NewIssues.handle_event(:tick, state)
    end
  end

  defp lease_for(
         %Connect.Connection{metadata: %{mode: :github_app, installation_id: id}} = connection,
         opts
       ) do
    AppAuth.installation_credential_lease(id, %{tenant_id: connection.tenant_id},
      connection_id: connection.id,
      github_client: Keyword.get(opts, :github_client, Jido.Connect.GitHub.Client)
    )
  end

  defp lease_for(%Connect.Connection{metadata: %{mode: :manual_token}} = connection, opts) do
    token =
      Keyword.get(opts, :access_token) ||
        Store.get_credential(connection.credential_ref)[:access_token] ||
        System.get_env("GITHUB_TOKEN")

    if blank?(token) do
      {:error, Error.config("GitHub token is required", key: "GITHUB_TOKEN")}
    else
      Connect.CredentialLease.new(%{
        connection_id: connection.id,
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        fields: %{
          access_token: token,
          github_client: Keyword.get(opts, :github_client, Jido.Connect.GitHub.Client)
        },
        metadata: %{mode: :manual_token}
      })
    end
  end

  defp blank?(value), do: is_nil(value) or value == ""
end
