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

    def get_thread_replies(
          %{channel: "C123", ts: "1700000000.000100", limit: 100},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         thread_ts: "1700000000.000100",
         messages: [
           %{
             type: "message",
             user: "U123",
             text: "Root",
             ts: "1700000000.000100",
             reply_count: 1,
             latest_reply: "1700000001.000200"
           },
           %{
             type: "message",
             user: "U456",
             text: "Reply",
             ts: "1700000001.000200",
             thread_ts: "1700000000.000100"
           }
         ],
         next_cursor: "next",
         has_more: true
       }}
    end

    def get_thread_replies(
          %{channel: "G123", ts: "1700000000.000100"},
          "token"
        ) do
      {:ok,
       %{
         channel: "G123",
         thread_ts: "1700000000.000100",
         messages: [],
         next_cursor: "",
         has_more: false
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

    def update_message(
          %{channel: "C123", ts: "1700000000.000100", text: "Updated"},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         ts: "1700000000.000100",
         message: %{text: "Updated"}
       }}
    end

    def delete_message(
          %{channel: "C123", ts: "1700000000.000100"},
          token
        )
        when token in ["token", "user-token"] do
      {:ok,
       %{
         channel: "C123",
         ts: "1700000000.000100"
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

    def list_users(%{limit: 100}, "token") do
      {:ok,
       %{
         users: [
           %{
             id: "U123",
             team_id: "T123",
             name: "ada",
             real_name: "Ada Lovelace",
             deleted: false,
             is_bot: false,
             is_app_user: false,
             profile: %{"email" => "ada@example.com"}
           }
         ],
         next_cursor: "next"
       }}
    end

    def user_info(%{user: "U123"}, "token") do
      {:ok,
       %{
         user: %{
           id: "U123",
           team_id: "T123",
           name: "ada",
           real_name: "Ada Lovelace",
           deleted: false,
           is_bot: false,
           is_app_user: false,
           profile: %{
             email: "ada@example.com",
             display_name: "ada",
             real_name: "Ada Lovelace"
           }
         }
       }}
    end

    def user_info(%{user: "B123"}, "token") do
      {:ok,
       %{
         user: %{
           id: "B123",
           team_id: "T123",
           name: "build-bot",
           real_name: "Build Bot",
           deleted: false,
           is_bot: true,
           is_app_user: false,
           profile: %{
             bot_id: "B999",
             display_name: "build-bot",
             real_name: "Build Bot"
           }
         }
       }}
    end

    def lookup_user_by_email(%{email: "ada@example.com"}, "token") do
      {:ok,
       %{
         user: %{
           id: "U123",
           team_id: "T123",
           name: "ada",
           real_name: "Ada Lovelace",
           deleted: false,
           is_bot: false,
           is_app_user: false,
           profile: %{
             email: "ada@example.com",
             display_name: "ada",
             real_name: "Ada Lovelace"
           }
         }
       }}
    end

    def lookup_user_by_email(%{email: "app@example.com"}, "token") do
      {:ok,
       %{
         user: %{
           id: "UAPP",
           team_id: "T123",
           name: "workflow-app",
           real_name: "Workflow App",
           deleted: false,
           is_bot: false,
           is_app_user: true,
           profile: %{}
         }
       }}
    end

    def lookup_user_by_email(%{email: "bot@example.com"}, "token") do
      {:ok,
       %{
         user: %{
           id: "B123",
           team_id: "T123",
           name: "build-bot",
           real_name: "Build Bot",
           deleted: false,
           is_bot: true,
           is_app_user: false,
           profile: nil
         }
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

    assert {:ok,
            %{
              id: "slack.thread.replies",
              resource: :thread,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["channels:history"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.thread.replies")

    assert {:ok, %{id: "slack.message.post", mutation?: true, confirmation: :required_for_ai}} =
             Connect.action(spec, "slack.message.post")

    assert {:ok, %{id: "slack.message.update", mutation?: true, confirmation: :required_for_ai}} =
             Connect.action(spec, "slack.message.update")

    assert {:ok,
            %{
              id: "slack.message.delete",
              mutation?: true,
              confirmation: :always,
              risk: :destructive,
              auth_profile: :bot,
              auth_profiles: [:bot, :user]
            }} =
             Connect.action(spec, "slack.message.delete")

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

    assert {:ok,
            %{
              id: "slack.user.list",
              resource: :user,
              verb: :list,
              policies: [:workspace_access],
              scopes: ["users:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.user.list")

    assert {:ok,
            %{
              id: "slack.user.info",
              resource: :user,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["users:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.user.info")

    assert {:ok,
            %{
              id: "slack.user.lookup_by_email",
              resource: :user,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["users:read.email"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.user.lookup_by_email")
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
             Jido.Connect.Slack.Actions.GetThreadReplies,
             Jido.Connect.Slack.Actions.AuthTest,
             Jido.Connect.Slack.Actions.TeamInfo,
             Jido.Connect.Slack.Actions.PostMessage,
             Jido.Connect.Slack.Actions.UpdateMessage,
             Jido.Connect.Slack.Actions.DeleteMessage,
             Jido.Connect.Slack.Actions.ListUsers,
             Jido.Connect.Slack.Actions.UserInfo,
             Jido.Connect.Slack.Actions.LookupUserByEmail
           ]

    assert Jido.Connect.Slack.jido_sensor_modules() == []
    assert Jido.Connect.Slack.jido_plugin_module() == Jido.Connect.Slack.Plugin

    assert %Connect.Catalog.Manifest{
             id: :slack,
             package: :jido_connect_slack,
             generated_modules: %{
               actions: [
                 Jido.Connect.Slack.Actions.ListChannels,
                 Jido.Connect.Slack.Actions.GetThreadReplies,
                 Jido.Connect.Slack.Actions.AuthTest,
                 Jido.Connect.Slack.Actions.TeamInfo,
                 Jido.Connect.Slack.Actions.PostMessage,
                 Jido.Connect.Slack.Actions.UpdateMessage,
                 Jido.Connect.Slack.Actions.DeleteMessage,
                 Jido.Connect.Slack.Actions.ListUsers,
                 Jido.Connect.Slack.Actions.UserInfo,
                 Jido.Connect.Slack.Actions.LookupUserByEmail
               ],
               sensors: [],
               plugin: Jido.Connect.Slack.Plugin
             }
           } = Jido.Connect.Slack.jido_connect_manifest()

    assert {:module, Jido.Connect.Slack.Actions.ListChannels} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ListChannels)

    assert {:module, Jido.Connect.Slack.Actions.GetThreadReplies} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.GetThreadReplies)

    assert {:module, Jido.Connect.Slack.Actions.AuthTest} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.AuthTest)

    assert {:module, Jido.Connect.Slack.Actions.TeamInfo} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.TeamInfo)

    assert {:module, Jido.Connect.Slack.Actions.ListUsers} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ListUsers)

    assert {:module, Jido.Connect.Slack.Actions.UserInfo} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.UserInfo)

    assert {:module, Jido.Connect.Slack.Actions.LookupUserByEmail} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.LookupUserByEmail)

    assert {:module, Jido.Connect.Slack.Actions.UpdateMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.UpdateMessage)

    assert {:module, Jido.Connect.Slack.Actions.DeleteMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.DeleteMessage)

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

    update_projection = Jido.Connect.Slack.Actions.UpdateMessage.jido_connect_projection()

    assert update_projection.action_id == "slack.message.update"
    assert update_projection.label == "Update message"
    assert update_projection.resource == :message
    assert update_projection.verb == :update

    assert Enum.map(update_projection.input, & &1.name) == [
             :channel,
             :ts,
             :text,
             :blocks
           ]

    assert update_projection.risk == :write
    assert update_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.UpdateMessage.name() == "slack_message_update"

    delete_projection = Jido.Connect.Slack.Actions.DeleteMessage.jido_connect_projection()

    assert delete_projection.action_id == "slack.message.delete"
    assert delete_projection.label == "Delete message"
    assert delete_projection.resource == :message
    assert delete_projection.verb == :delete

    assert Enum.map(delete_projection.input, & &1.name) == [
             :channel,
             :ts
           ]

    assert Enum.map(delete_projection.output, & &1.name) == [
             :channel,
             :ts
           ]

    assert delete_projection.risk == :destructive
    assert delete_projection.confirmation == :always
    assert delete_projection.auth_profile == :bot
    assert delete_projection.auth_profiles == [:bot, :user]
    assert Jido.Connect.Slack.Actions.DeleteMessage.name() == "slack_message_delete"

    list_projection = Jido.Connect.Slack.Actions.ListChannels.jido_connect_projection()
    assert list_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    replies_projection = Jido.Connect.Slack.Actions.GetThreadReplies.jido_connect_projection()
    assert replies_projection.action_id == "slack.thread.replies"
    assert replies_projection.resource == :thread
    assert replies_projection.verb == :read
    assert replies_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(replies_projection.input, & &1.name) == [
             :channel,
             :ts,
             :conversation_type,
             :limit,
             :cursor,
             :oldest,
             :latest,
             :inclusive
           ]

    assert Enum.map(replies_projection.output, & &1.name) == [
             :channel,
             :thread_ts,
             :messages,
             :reply_count,
             :latest_reply,
             :next_cursor,
             :has_more
           ]

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

    user_projection = Jido.Connect.Slack.Actions.ListUsers.jido_connect_projection()
    assert user_projection.action_id == "slack.user.list"
    assert user_projection.resource == :user
    assert user_projection.verb == :list

    assert Enum.map(user_projection.input, & &1.name) == [
             :limit,
             :cursor,
             :team_id,
             :include_locale
           ]

    assert Enum.map(user_projection.output, & &1.name) == [:users, :next_cursor]

    user_info_projection = Jido.Connect.Slack.Actions.UserInfo.jido_connect_projection()
    assert user_info_projection.action_id == "slack.user.info"
    assert user_info_projection.resource == :user
    assert user_info_projection.verb == :read

    assert Enum.map(user_info_projection.input, & &1.name) == [
             :user,
             :include_locale
           ]

    assert Enum.map(user_info_projection.output, & &1.name) == [
             :user_id,
             :team_id,
             :name,
             :real_name,
             :tz,
             :deleted,
             :is_bot,
             :is_app_user,
             :user_type,
             :bot_id,
             :updated,
             :profile,
             :user
           ]

    lookup_user_projection =
      Jido.Connect.Slack.Actions.LookupUserByEmail.jido_connect_projection()

    assert lookup_user_projection.action_id == "slack.user.lookup_by_email"
    assert lookup_user_projection.resource == :user
    assert lookup_user_projection.verb == :read
    assert lookup_user_projection.scopes == ["users:read.email"]

    assert Enum.map(lookup_user_projection.input, & &1.name) == [
             :email
           ]

    assert Enum.map(lookup_user_projection.output, & &1.name) == [
             :user_id,
             :team_id,
             :name,
             :real_name,
             :tz,
             :deleted,
             :is_bot,
             :is_app_user,
             :user_type,
             :bot_id,
             :updated,
             :profile,
             :user
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

  test "generated get thread replies action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              thread_ts: "1700000000.000100",
              messages: [
                %{text: "Root", ts: "1700000000.000100", reply_count: 1},
                %{text: "Reply", thread_ts: "1700000000.000100"}
              ],
              reply_count: 1,
              latest_reply: "1700000001.000200",
              next_cursor: "next",
              has_more: true
            }} =
             Jido.Connect.Slack.Actions.GetThreadReplies.run(
               %{channel: "C123", ts: "1700000000.000100", limit: 100},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "get thread replies resolves history scopes from conversation type" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:history"]
            }} =
             Jido.Connect.Slack.Actions.GetThreadReplies.run(
               %{channel: "G123", ts: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )

    private_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes ++ ["groups:history"]
        }
    }

    assert {:ok, %{channel: "G123", thread_ts: "1700000000.000100"}} =
             Jido.Connect.Slack.Actions.GetThreadReplies.run(
               %{channel: "G123", ts: "1700000000.000100"},
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

  test "generated update message action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100",
              message: %{text: "Updated"}
            }} =
             Jido.Connect.Slack.Actions.UpdateMessage.run(
               %{channel: "C123", ts: "1700000000.000100", text: "Updated"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated delete message action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100"
            }} =
             Jido.Connect.Slack.Actions.DeleteMessage.run(
               %{channel: "C123", ts: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated delete message action accepts Slack user-token connections" do
    {context, lease} = context_and_lease(profile: :user, access_token: "user-token")

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100"
            }} =
             Jido.Connect.Slack.Actions.DeleteMessage.run(
               %{channel: "C123", ts: "1700000000.000100"},
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

  test "generated list users action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              users: [
                %{
                  id: "U123",
                  team_id: "T123",
                  name: "ada",
                  real_name: "Ada Lovelace",
                  profile: %{"email" => "ada@example.com"}
                }
              ],
              next_cursor: "next"
            }} =
             Jido.Connect.Slack.Actions.ListUsers.run(
               %{limit: 100},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated user info action distinguishes user and bot profiles" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              user_id: "U123",
              team_id: "T123",
              name: "ada",
              real_name: "Ada Lovelace",
              is_bot: false,
              is_app_user: false,
              user_type: "user",
              profile: %{
                email: "ada@example.com",
                display_name: "ada",
                real_name: "Ada Lovelace"
              },
              user: %{id: "U123"}
            }} =
             Jido.Connect.Slack.Actions.UserInfo.run(
               %{user: "U123"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:ok,
            %{
              user_id: "B123",
              name: "build-bot",
              is_bot: true,
              user_type: "bot",
              bot_id: "B999",
              profile: %{bot_id: "B999", display_name: "build-bot"}
            }} =
             Jido.Connect.Slack.Actions.UserInfo.run(
               %{user: "B123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated lookup user by email action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              user_id: "U123",
              team_id: "T123",
              name: "ada",
              real_name: "Ada Lovelace",
              user_type: "user",
              profile: %{
                email: "ada@example.com",
                display_name: "ada",
                real_name: "Ada Lovelace"
              },
              user: %{id: "U123"}
            }} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "ada@example.com"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:ok, %{user_id: "UAPP", user_type: "app_user"} = app_user} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "app@example.com"},
               %{integration_context: context, credential_lease: lease}
             )

    refute Map.has_key?(app_user, :profile)

    assert {:ok, %{user_id: "B123", user_type: "bot"} = bot_user} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "bot@example.com"},
               %{integration_context: context, credential_lease: lease}
             )

    refute Map.has_key?(bot_user, :profile)
  end

  test "lookup user by email returns config errors from missing client" do
    {context, lease} = context_and_lease()

    lease = %{lease | fields: %{access_token: "token"}}

    assert {:error,
            %Connect.Error.ConfigError{
              key: :slack_client,
              message: "Slack client module is required"
            }} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "ada@example.com"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "lookup user by email requires Slack email scope" do
    {context, lease} = context_and_lease()

    context = %{
      context
      | connection: %{
          context.connection
          | scopes: ["channels:read", "chat:write", "team:read", "users:read"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["users:read.email"]
            }} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "ada@example.com"},
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
             Jido.Connect.Slack.Actions.GetThreadReplies,
             Jido.Connect.Slack.Actions.AuthTest,
             Jido.Connect.Slack.Actions.TeamInfo,
             Jido.Connect.Slack.Actions.PostMessage,
             Jido.Connect.Slack.Actions.UpdateMessage,
             Jido.Connect.Slack.Actions.DeleteMessage,
             Jido.Connect.Slack.Actions.ListUsers,
             Jido.Connect.Slack.Actions.UserInfo,
             Jido.Connect.Slack.Actions.LookupUserByEmail
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

  defp context_and_lease(opts \\ []) do
    profile = Keyword.get(opts, :profile, :bot)
    access_token = Keyword.get(opts, :access_token, "token")

    connection =
      Connect.Connection.new!(%{
        id: "slack-team-T123",
        provider: :slack,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: if(profile == :user, do: :user, else: :tenant),
        owner_id: if(profile == :user, do: "user_1", else: "T123"),
        status: :connected,
        scopes: [
          "channels:read",
          "channels:history",
          "chat:write",
          "team:read",
          "users:read",
          "users:read.email"
        ]
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
        fields: %{access_token: access_token, slack_client: FakeSlackClient}
      })

    {context, lease}
  end
end
