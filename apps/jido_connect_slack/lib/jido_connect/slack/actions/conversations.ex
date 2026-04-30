defmodule Jido.Connect.Slack.Actions.Conversations do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_channels do
      id "slack.channel.list"
      resource :channel
      verb :list
      data_classification :workspace_metadata
      label "List channels"
      description "List Slack conversations visible to the installed app."
      handler Jido.Connect.Slack.Handlers.Actions.ListChannels
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :types, :string, default: "public_channel"
        field :exclude_archived, :boolean, default: true
        field :limit, :integer, default: 100
        field :cursor, :string
        field :team_id, :string
      end

      output do
        field :channels, {:array, :map}
        field :next_cursor, :string
      end
    end

    action :get_thread_replies do
      id "slack.thread.replies"
      resource :thread
      verb :read
      data_classification :message_content
      label "Get thread replies"
      description "Fetch replies for a Slack message thread."
      handler Jido.Connect.Slack.Handlers.Actions.GetThreadReplies
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:history"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :ts, :string, required?: true, description: "Slack parent message timestamp."

        field :conversation_type, :string,
          description:
            "Optional Slack conversation type: public_channel, private_channel, im, or mpim."

        field :limit, :integer, default: 100
        field :cursor, :string
        field :oldest, :string
        field :latest, :string
        field :inclusive, :boolean, default: false
      end

      output do
        field :channel, :string
        field :thread_ts, :string
        field :messages, {:array, :map}
        field :reply_count, :integer
        field :latest_reply, :string
        field :next_cursor, :string
        field :has_more, :boolean
      end
    end
  end
end
