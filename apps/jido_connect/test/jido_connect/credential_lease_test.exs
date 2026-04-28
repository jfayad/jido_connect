defmodule Jido.Connect.CredentialLeaseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Connection, CredentialLease}

  test "inspect redacts credential field values" do
    lease =
      CredentialLease.new!(%{
        connection_id: "github-installation-1",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        fields: %{access_token: "secret-token", refresh_token: "secret-refresh"},
        metadata: %{installation_id: 1, private_key: "secret-key"}
      })

    inspected = inspect(lease)

    assert inspected =~ "github-installation-1"
    assert inspected =~ "access_token"
    assert inspected =~ "refresh_token"
    refute inspected =~ "secret-token"
    refute inspected =~ "secret-refresh"
    refute inspected =~ "secret-key"
  end

  test "from_connection builds a portable runtime auth envelope" do
    connection = connection()

    assert {:ok, lease} =
             CredentialLease.from_connection(
               connection,
               %{access_token: "secret-token"},
               expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
               metadata: %{issued_by: :test}
             )

    assert lease.connection_id == "conn_1"
    assert lease.provider == :github
    assert lease.profile == :installation
    assert lease.tenant_id == "tenant_1"
    assert lease.owner_type == :tenant
    assert lease.owner_id == "tenant_1"
    assert lease.subject == %{account_login: "acme"}
    assert lease.scopes == ["metadata:read", "issues:read"]
    assert lease.metadata == %{issued_by: :test}
    assert CredentialLease.matches_connection?(lease, connection)
    assert CredentialLease.effective_scopes(lease, connection) == ["metadata:read", "issues:read"]
    assert CredentialLease.fetch_field(lease, :access_token) == {:ok, "secret-token"}
    assert CredentialLease.get_field(lease, "access_token") == "secret-token"
    assert CredentialLease.fetch_field(lease, :missing) == :error
    refute CredentialLease.expired?(lease)
    assert :ok = CredentialLease.require_unexpired(lease)
  end

  test "to_public_map describes a lease without raw credential values" do
    lease =
      CredentialLease.from_connection!(
        connection(),
        %{access_token: "secret-token", private_key: "secret-key"},
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        metadata: %{private_key: "secret-key", installation_id: 123}
      )

    public = CredentialLease.to_public_map(lease)

    assert public.connection_id == "conn_1"
    assert public.provider == :github
    assert Enum.sort(public.field_keys) == [:access_token, :private_key]
    assert public.metadata["private_key"] == "[redacted]"
    assert public.metadata["installation_id"] == 123
    assert CredentialLease.ttl_seconds(lease) > 0

    refute inspect(public) =~ "secret-token"
    refute inspect(public) =~ "secret-key"
  end

  test "nil scopes fall back to connection scopes while explicit empty scopes are enforced" do
    connection = connection()

    legacy_lease =
      CredentialLease.new!(%{
        connection_id: connection.id,
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        fields: %{}
      })

    scoped_lease = %{legacy_lease | scopes: []}

    assert CredentialLease.effective_scopes(legacy_lease, connection) == connection.scopes
    assert CredentialLease.effective_scopes(scoped_lease, connection) == []
  end

  test "connection binding validates copied provider and owner metadata" do
    connection = connection()

    lease =
      CredentialLease.from_connection!(
        connection,
        %{},
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      )

    assert :ok = CredentialLease.validate_connection_binding(lease, connection)

    mismatched = %{lease | owner_id: "other"}

    assert {:error,
            %Jido.Connect.Error.AuthError{
              reason: :credential_connection_mismatch,
              details: %{field: :owner_id, expected: "tenant_1", actual: "other"}
            }} = CredentialLease.validate_connection_binding(mismatched, connection)

    refute CredentialLease.matches_connection?(mismatched, connection)
  end

  defp connection do
    Connection.new!(%{
      id: "conn_1",
      provider: :github,
      profile: :installation,
      tenant_id: "tenant_1",
      owner_type: :tenant,
      owner_id: "tenant_1",
      subject: %{account_login: "acme"},
      status: :connected,
      scopes: ["metadata:read", "issues:read"]
    })
  end
end
