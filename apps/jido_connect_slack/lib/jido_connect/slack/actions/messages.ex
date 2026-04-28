defmodule Jido.Connect.Slack.Actions.Messages do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :post_message do
      id "slack.message.post"
      resource :message
      verb :create
      data_classification :message_content
      label "Post message"
      description "Post a message to a Slack channel or conversation."
      handler Jido.Connect.Slack.Handlers.Actions.PostMessage
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :text, :string, required?: true
        field :thread_ts, :string
        field :reply_broadcast, :boolean, default: false
      end

      output do
        field :channel, :string
        field :ts, :string
        field :message, :map
      end
    end
  end
end
