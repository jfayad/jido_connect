defmodule Jido.Connect.Slack.Actions.Reactions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_reactions do
      id "slack.reaction.list"
      resource :reaction
      verb :list
      data_classification :workspace_metadata
      label "List reactions"
      description "List emoji reactions for a Slack message or file target."
      handler Jido.Connect.Slack.Handlers.Actions.ListReactions

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["reactions:read"]
      end

      input do
        field :channel, :string, example: "C012AB3CD"
        field :timestamp, :string, description: "Slack message timestamp."
        field :file, :string, example: "F012AB3CD"
        field :file_comment, :string
        field :full, :boolean, default: false
      end

      output do
        field :type, :string
        field :channel, :string
        field :timestamp, :string
        field :file_id, :string
        field :file_comment_id, :string
        field :message, :map
        field :file, :map
        field :file_comment, :map
        field :reactions, {:array, :map}
      end
    end

    action :add_reaction do
      id "slack.reaction.add"
      resource :reaction
      verb :create
      data_classification :workspace_metadata
      label "Add reaction"
      description "Add an emoji reaction to a Slack message by channel and timestamp."
      handler Jido.Connect.Slack.Handlers.Actions.AddReaction
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["reactions:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :timestamp, :string, required?: true, description: "Slack message timestamp."
        field :name, :string, required?: true, example: "thumbsup"
      end

      output do
        field :channel, :string
        field :timestamp, :string
        field :name, :string
      end
    end

    action :remove_reaction do
      id "slack.reaction.remove"
      resource :reaction
      verb :delete
      data_classification :workspace_metadata
      label "Remove reaction"
      description "Remove an emoji reaction from a Slack message by channel and timestamp."
      handler Jido.Connect.Slack.Handlers.Actions.RemoveReaction
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["reactions:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :timestamp, :string, required?: true, description: "Slack message timestamp."
        field :name, :string, required?: true, example: "thumbsup"
      end

      output do
        field :channel, :string
        field :timestamp, :string
        field :name, :string
      end
    end
  end
end
