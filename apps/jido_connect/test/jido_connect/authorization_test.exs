defmodule Jido.Connect.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Authorization, Connection, Context, CredentialLease, Error}

  test "authorizes a connected operation with a matching active lease" do
    connection = connection()
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{access_token: "secret"},
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert :ok = Authorization.authorize(operation(), %{repo: "org/repo"}, context, lease)
  end

  test "lease scopes narrow durable connection scopes" do
    connection = connection(scopes: ["repo", "admin:org"])
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{},
        scopes: ["repo"],
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert :ok = Authorization.authorize(operation(scopes: ["repo"]), %{}, context, lease)

    assert {:error, %Error.AuthError{reason: :missing_scopes, missing_scopes: ["admin:org"]}} =
             Authorization.authorize(operation(scopes: ["admin:org"]), %{}, context, lease)
  end

  test "rejects connection and lease binding mismatches before provider execution" do
    connection = connection()
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{},
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert {:error, %Error.AuthError{reason: :credential_connection_mismatch}} =
             Authorization.authorize(operation(), %{}, context, %{lease | tenant_id: "other"})

    assert {:error, %Error.AuthError{reason: :credential_connection_mismatch}} =
             Authorization.authorize(operation(), %{}, context, %{lease | connection_id: "other"})
  end

  test "connection availability is lease-free and policy aware" do
    assert {:available, ["repo"]} =
             Authorization.connection_availability(operation(), connection(), %{})

    assert {:missing_scopes, ["repo"]} =
             Authorization.connection_availability(operation(), connection(scopes: []), %{})

    assert :connection_required =
             Authorization.connection_availability(operation(), connection(status: :revoked), %{})

    assert :connection_required =
             Authorization.connection_availability(
               operation(auth_profiles: [:installation]),
               connection(profile: :user),
               %{}
             )
  end

  defp operation(attrs \\ []) do
    %{
      id: "github.issue.list",
      auth_profile: Keyword.get(attrs, :auth_profile, :user),
      auth_profiles: Keyword.get(attrs, :auth_profiles, [:user]),
      scopes: Keyword.get(attrs, :scopes, ["repo"])
    }
  end

  defp context(connection) do
    Context.new!(%{
      tenant_id: connection.tenant_id,
      actor: %{id: connection.owner_id, type: connection.owner_type},
      connection: connection
    })
  end

  defp connection(attrs \\ []) do
    Connection.new!(%{
      id: Keyword.get(attrs, :id, "conn_1"),
      provider: Keyword.get(attrs, :provider, :github),
      profile: Keyword.get(attrs, :profile, :user),
      tenant_id: Keyword.get(attrs, :tenant_id, "tenant_1"),
      owner_type: Keyword.get(attrs, :owner_type, :user),
      owner_id: Keyword.get(attrs, :owner_id, "user_1"),
      status: Keyword.get(attrs, :status, :connected),
      scopes: Keyword.get(attrs, :scopes, ["repo"])
    })
  end
end
