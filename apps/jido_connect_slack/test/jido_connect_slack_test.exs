defmodule Jido.Connect.SlackTest do
  use ExUnit.Case

  alias Jido.Connect

  defmodule FakeSlackClient do
    def list_channels(%{types: "public_channel"}, "token") do
      {:ok,
       %{
         channels: [
           %{
             id: "C123",
             name: "general",
             is_archived: false,
             is_private: false,
             is_member: true
           }
         ],
         next_cursor: ""
       }}
    end

    def list_channels(%{types: "private_channel"}, "token") do
      {:ok,
       %{
         channels: [
           %{
             id: "G123",
             name: "private",
             is_archived: false,
             is_private: true,
             is_member: true
           }
         ],
         next_cursor: ""
       }}
    end

    def post_message(
          %{channel: "C123", text: "Hello", reply_broadcast: false},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         ts: "1700000000.000100",
         message: %{text: "Hello"}
       }}
    end

    def auth_test("token") do
      {:ok,
       %{
         "team_id" => "T123",
         "team" => "Demo",
         "url" => "https://demo.slack.com/",
         "user_id" => "U123",
         "user" => "demo-user",
         "bot_id" => "B123",
         "enterprise_id" => "E123",
         "is_enterprise_install" => true
       }}
    end

    def team_info(%{team_id: "T123"}, "token") do
      {:ok,
       %{
         team: %{
           "id" => "T123",
           "name" => "Demo",
           "domain" => "demo",
           "email_domain" => "demo.example",
           "enterprise_id" => "E123",
           "enterprise_name" => "Example Enterprise"
         }
       }}
    end
  end

  test "Slack integration declares first actions" do
    spec = Jido.Connect.Slack.integration()

    assert spec.id == :slack
    assert spec.package == :jido_connect_slack
    assert spec.tags == [:chat, :collaboration, :messaging]
    assert [%{id: :workspace_access}] = spec.policies

    assert {:ok,
            %{
              id: "slack.channel.list",
              resource: :channel,
              verb: :list,
              policies: [:workspace_access],
              mutation?: false
            }} =
             Connect.action(spec, "slack.channel.list")

    assert {:ok, %{id: "slack.message.post", mutation?: true, confirmation: :required_for_ai}} =
             Connect.action(spec, "slack.message.post")

    assert {:ok,
            %{
              id: "slack.auth.test",
              resource: :auth,
              verb: :read,
              policies: [:workspace_access],
              mutation?: false
            }} =
             Connect.action(spec, "slack.auth.test")

    assert {:ok,
            %{
              id: "slack.team.info",
              resource: :team,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["team:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.team.info")
  end

  test "Slack catalog entry exposes setup, auth, and runtime capabilities" do
    entry = Connect.Catalog.entry(Jido.Connect.Slack)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_slack
    assert MapSet.member?(features, :oauth2)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :slack_app_manifest)
    assert MapSet.member?(features, :signed_request_verification)
  end

  test "Slack integration compiles generated Jido modules" do
    assert Application.get_env(:jido_connect_slack, :jido_connect_providers) == [
             Jido.Connect.Slack
           ]

    assert Jido.Connect.Slack.jido_action_modules() == [
             Jido.Connect.Slack.Actions.ListChannels,
             Jido.Connect.Slack.Actions.AuthTest,
             Jido.Connect.Slack.Actions.TeamInfo,
             Jido.Connect.Slack.Actions.PostMessage
           ]

    assert Jido.Connect.Slack.jido_sensor_modules() == []
    assert Jido.Connect.Slack.jido_plugin_module() == Jido.Connect.Slack.Plugin

    assert %Connect.Catalog.Manifest{
             id: :slack,
             package: :jido_connect_slack,
             generated_modules: %{
               actions: [
                 Jido.Connect.Slack.Actions.ListChannels,
                 Jido.Connect.Slack.Actions.AuthTest,
                 Jido.Connect.Slack.Actions.TeamInfo,
                 Jido.Connect.Slack.Actions.PostMessage
               ],
               sensors: [],
               plugin: Jido.Connect.Slack.Plugin
             }
           } = Jido.Connect.Slack.jido_connect_manifest()

    assert {:module, Jido.Connect.Slack.Actions.ListChannels} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ListChannels)

    assert {:module, Jido.Connect.Slack.Actions.AuthTest} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.AuthTest)

    assert {:module, Jido.Connect.Slack.Actions.TeamInfo} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.TeamInfo)

    assert {:module, Jido.Connect.Slack.Plugin} =
             Code.ensure_loaded(Jido.Connect.Slack.Plugin)

    assert function_exported?(Jido.Connect.Slack.Actions.ListChannels, :run, 2)
    assert function_exported?(Jido.Connect.Slack.Plugin, :plugin_spec, 1)
  end

  test "generated action metadata tracks the DSL action" do
    projection = Jido.Connect.Slack.Actions.PostMessage.jido_connect_projection()

    assert projection.action_id == "slack.message.post"
    assert projection.label == "Post message"
    assert projection.resource == :message
    assert projection.verb == :create
    assert projection.policies == [:workspace_access]

    assert Enum.map(projection.input, & &1.name) == [
             :channel,
             :text,
             :thread_ts,
             :reply_broadcast
           ]

    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.PostMessage.name() == "slack_message_post"

    list_projection = Jido.Connect.Slack.Actions.ListChannels.jido_connect_projection()
    assert list_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    auth_projection = Jido.Connect.Slack.Actions.AuthTest.jido_connect_projection()
    assert auth_projection.action_id == "slack.auth.test"
    assert auth_projection.resource == :auth
    assert auth_projection.verb == :read

    team_projection = Jido.Connect.Slack.Actions.TeamInfo.jido_connect_projection()
    assert team_projection.action_id == "slack.team.info"

    assert Enum.map(team_projection.output, & &1.name) == [
             :team_id,
             :name,
             :domain,
             :email_domain,
             :enterprise_id,
             :enterprise_name,
             :team
           ]
  end

  test "generated list channels action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{channels: [%{id: "C123", name: "general"}], next_cursor: ""}} =
             Jido.Connect.Slack.Actions.ListChannels.run(
               %{types: "public_channel"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "list channels resolves scopes from requested conversation types" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["groups:read"]}} =
             Jido.Connect.Slack.Actions.ListChannels.run(
               %{types: "private_channel"},
               %{integration_context: context, credential_lease: lease}
             )

    private_context = %{
      context
      | connection: %{
          context.connection
          | scopes: ["channels:read", "groups:read", "chat:write"]
        }
    }

    assert {:ok, %{channels: [%{id: "G123", name: "private"}], next_cursor: ""}} =
             Jido.Connect.Slack.Actions.ListChannels.run(
               %{types: "private_channel"},
               %{integration_context: private_context, credential_lease: lease}
             )
  end

  test "generated post message action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100",
              message: %{text: "Hello"}
            }} =
             Jido.Connect.Slack.Actions.PostMessage.run(
               %{channel: "C123", text: "Hello"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated auth test action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              team_id: "T123",
              team: "Demo",
              user_id: "U123",
              user: "demo-user",
              bot_id: "B123",
              enterprise_id: "E123",
              is_enterprise_install: true
            }} =
             Jido.Connect.Slack.Actions.AuthTest.run(
               %{},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated team info action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              team_id: "T123",
              name: "Demo",
              domain: "demo",
              email_domain: "demo.example",
              enterprise_id: "E123",
              enterprise_name: "Example Enterprise",
              team: %{"id" => "T123"}
            }} =
             Jido.Connect.Slack.Actions.TeamInfo.run(
               %{team_id: "T123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated plugin filters actions and reports availability" do
    spec = Jido.Connect.Slack.Plugin.plugin_spec(%{})

    assert spec.actions == [
             Jido.Connect.Slack.Actions.ListChannels,
             Jido.Connect.Slack.Actions.AuthTest,
             Jido.Connect.Slack.Actions.TeamInfo,
             Jido.Connect.Slack.Actions.PostMessage
           ]

    filtered =
      Jido.Connect.Slack.Plugin.plugin_spec(%{
        allowed_actions: ["slack.channel.list"]
      })

    assert filtered.actions == [Jido.Connect.Slack.Actions.ListChannels]

    [list_available | _] =
      Jido.Connect.Slack.Plugin.tool_availability(%{
        connection: elem(context_and_lease(), 0).connection
      })

    assert list_available.state == :available

    [missing_scopes | _] =
      Jido.Connect.Slack.Plugin.tool_availability(%{
        connection: %{elem(context_and_lease(), 0).connection | scopes: []}
      })

    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["channels:read"]
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "slack-team-T123",
        provider: :slack,
        profile: :bot,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "T123",
        status: :connected,
        scopes: ["channels:read", "chat:write", "team:read"]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "slack-team-T123",
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", slack_client: FakeSlackClient}
      })

    {context, lease}
  end
end
