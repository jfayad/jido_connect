defmodule Jido.Connect.CredentialLeaseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.CredentialLease

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
end
