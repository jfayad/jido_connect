defmodule Jido.Connect.Slack do
  @moduledoc """
  Slack integration authored with the `Jido.Connect` Spark DSL.

  This module compiles into hidden generated adapter modules under
  provider-specific Actions and Plugin namespaces.
  """

  use Jido.Connect

  integration do
    id(:slack)
    name("Slack")
    category(:collaboration)
    docs(["https://docs.slack.dev/apis/web-api", "https://docs.slack.dev/events-api"])
    metadata(%{package: :jido_connect_slack})
  end

  auth do
    oauth2 :bot do
      default?(true)
      owner(:tenant)
      subject(:bot)
      label("Slack bot OAuth")
      authorize_url("https://slack.com/oauth/v2/authorize")
      token_url("https://slack.com/api/oauth.v2.access")
      callback_path("/integrations/slack/oauth/callback")
      token_field(:access_token)
      scopes(["channels:read", "groups:read", "im:read", "mpim:read", "chat:write"])
      default_scopes(["channels:read", "chat:write"])
      pkce?(false)
      refresh?(false)
      revoke?(false)
    end
  end

  actions do
    action :list_channels do
      id("slack.channel.list")
      label("List channels")
      description("List Slack conversations visible to the installed app.")
      auth(:bot)
      scopes(["channels:read"])
      scope_resolver(Jido.Connect.Slack.ScopeResolver)
      mutation?(false)
      risk(:read)
      handler(Jido.Connect.Slack.Handlers.Actions.ListChannels)

      input do
        field(:types, :string, default: "public_channel")
        field(:exclude_archived, :boolean, default: true)
        field(:limit, :integer, default: 100)
        field(:cursor, :string)
        field(:team_id, :string)
      end

      output do
        field(:channels, {:array, :map})
        field(:next_cursor, :string)
      end
    end

    action :post_message do
      id("slack.message.post")
      label("Post message")
      description("Post a message to a Slack channel or conversation.")
      auth(:bot)
      scopes(["chat:write"])
      mutation?(true)
      risk(:write)
      confirmation(:required_for_ai)
      handler(Jido.Connect.Slack.Handlers.Actions.PostMessage)

      input do
        field(:channel, :string, required?: true, example: "C012AB3CD")
        field(:text, :string, required?: true)
        field(:thread_ts, :string)
        field(:reply_broadcast, :boolean, default: false)
      end

      output do
        field(:channel, :string)
        field(:ts, :string)
        field(:message, :map)
      end
    end
  end
end
