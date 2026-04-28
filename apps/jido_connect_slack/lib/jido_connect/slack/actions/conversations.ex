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
  end
end
