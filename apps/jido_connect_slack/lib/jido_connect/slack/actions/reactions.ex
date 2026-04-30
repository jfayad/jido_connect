defmodule Jido.Connect.Slack.Actions.Reactions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
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
  end
end
