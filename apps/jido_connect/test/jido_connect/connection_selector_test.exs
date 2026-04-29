defmodule Jido.Connect.ConnectionSelectorTest do
  use ExUnit.Case, async: true

  alias Jido.Connect

  test "connection selectors model shared credential lookup intent" do
    assert {:ok,
            %Connect.ConnectionSelector{
              provider: :github,
              strategy: :per_actor,
              tenant_id: "tenant_1",
              actor_id: "user_1",
              owner_type: :user,
              owner_id: "user_1"
            } = per_actor} =
             Connect.ConnectionSelector.per_actor(:github, "tenant_1", "user_1", profile: :user)

    assert {:ok,
            %Connect.ConnectionSelector{
              strategy: :tenant_default,
              owner_type: :tenant,
              owner_id: "tenant_1"
            }} =
             Connect.ConnectionSelector.tenant_default(:slack, "tenant_1", profile: :bot)

    assert {:ok,
            %Connect.ConnectionSelector{
              strategy: :org_default,
              owner_type: :org,
              owner_id: "org_1"
            }} =
             Connect.ConnectionSelector.org_default(:github, "tenant_1", "org_1",
               profile: :installation
             )

    assert {:ok,
            %Connect.ConnectionSelector{
              strategy: :installation,
              owner_type: :installation,
              owner_id: "installation_1"
            }} =
             Connect.ConnectionSelector.installation(:github, "tenant_1", "installation_1",
               profile: :installation
             )

    assert {:ok, %Connect.ConnectionSelector{strategy: :system, owner_type: :system}} =
             Connect.ConnectionSelector.system(:stripe, profile: :api_key)

    assert {:ok, %Connect.ConnectionSelector{strategy: :explicit, connection_id: "conn_1"}} =
             Connect.ConnectionSelector.explicit(:github, "conn_1", profile: :user)

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :github,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["repo"]
      })

    assert {:ok, ^connection} =
             Connect.ConnectionSelector.resolve(per_actor, fn ^per_actor -> connection end)

    assert Connect.ConnectionSelector.matches_connection?(per_actor, connection)
    assert Connect.ConnectionSelector.selector_mismatch(per_actor, connection) == nil
    assert Connect.ConnectionSelector.missing_scopes(per_actor, connection) == []

    assert {:ok, explicit_selector} = Connect.ConnectionSelector.from_connection(connection)
    assert explicit_selector.strategy == :explicit
    assert explicit_selector.connection_id == "conn_1"
    assert Connect.ConnectionSelector.matches_connection?(explicit_selector, connection)

    missing_scope_selector = %{per_actor | required_scopes: ["repo", "admin:org"]}

    assert Connect.ConnectionSelector.missing_scopes(missing_scope_selector, connection) == [
             "admin:org"
           ]

    assert Connect.ConnectionSelector.selector_mismatch(missing_scope_selector, connection) ==
             {:required_scopes, ["admin:org"], ["repo"]}

    assert Connect.ConnectionSelector.selector_mismatch(
             %{per_actor | owner_id: "other"},
             connection
           ) ==
             {:owner_id, "other", "user_1"}

    assert {:ok, ^per_actor} = Connect.ConnectionSelector.normalize(Map.from_struct(per_actor))
  end
end
