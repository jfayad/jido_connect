defmodule Jido.Connect.InvokeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect

  defmodule Handler do
    def run(_input, _context), do: {:error, :handler_should_not_run}
  end

  test "authenticated actions require a connection before handler execution" do
    spec =
      Connect.Spec.new!(%{
        id: :demo,
        name: "Demo",
        auth_profiles: [
          Connect.AuthProfile.new!(%{
            id: :user,
            kind: :oauth2,
            owner: :user,
            subject: :user,
            label: "User"
          })
        ],
        actions: [
          Connect.ActionSpec.new!(%{
            id: "demo.action",
            name: :demo_action,
            label: "Demo action",
            auth_profile: :user,
            handler: Handler,
            input_schema: Zoi.object(%{}),
            output_schema: Zoi.object(%{})
          })
        ],
        triggers: []
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user}
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token"}
      })

    assert {:error, :connection_required} =
             Connect.invoke(spec, "demo.action", %{},
               context: context,
               credential_lease: lease
             )
  end
end
