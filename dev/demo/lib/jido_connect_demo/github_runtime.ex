defmodule Jido.Connect.Demo.GitHubRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Demo.Store
  alias Jido.Connect.GitHub.AppAuth
  alias Jido.Connect.GitHub.Connections

  def create_manual_connection(attrs) do
    token = Map.get(attrs, "token") || System.get_env("GITHUB_TOKEN")
    owner_id = Map.get(attrs, "owner_id", "local-user")
    tenant_id = Map.get(attrs, "tenant_id", "local")
    credential_ref = "demo:github-manual-#{owner_id}"

    {:ok, connection} =
      Connections.user_connection(%{scope: ["repo", "read:user"]},
        id: "github-manual-#{owner_id}",
        tenant_id: tenant_id,
        owner_type: :user,
        owner_id: owner_id,
        status: if(blank?(token), do: :needs_credentials, else: :connected),
        credential_ref: credential_ref,
        metadata: %{mode: :manual_token}
      )

    if not blank?(token), do: Store.put_credential(credential_ref, %{access_token: token})

    Store.put_connection(connection)
  end

  def create_installation_connection(installation_id, attrs \\ %{}) do
    tenant_id = Map.get(attrs, "tenant_id", "local")

    installation =
      %{
        id: installation_id,
        account: %{
          login: Map.get(attrs, "account_login"),
          id: Map.get(attrs, "account_id"),
          type: Map.get(attrs, "account_type")
        },
        repository_selection: Map.get(attrs, "repository_selection")
      }

    connection_opts =
      [
        tenant_id: tenant_id,
        owner_id: Map.get(attrs, "owner_id")
      ]
      |> maybe_put(:owner_type, owner_type(attrs))
      |> Enum.reject(fn {_key, value} -> blank?(value) end)

    {:ok, connection} = Connections.installation_connection(installation, connection_opts)

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
      connection: connection,
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
      Connect.CredentialLease.from_connection(
        connection,
        %{
          access_token: token,
          github_client: Keyword.get(opts, :github_client, Jido.Connect.GitHub.Client)
        },
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        metadata: %{mode: :manual_token}
      )
    end
  end

  defp blank?(value), do: is_nil(value) or value == ""

  defp owner_type(%{"owner_type" => owner_type})
       when owner_type in ["tenant", "app_user", "user"],
       do: String.to_existing_atom(owner_type)

  defp owner_type(_attrs), do: nil

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
