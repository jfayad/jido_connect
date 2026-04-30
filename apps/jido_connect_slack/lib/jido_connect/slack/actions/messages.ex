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

    action :update_message do
      id "slack.message.update"
      resource :message
      verb :update
      data_classification :message_content
      label "Update message"
      description "Update a Slack message by channel and timestamp."
      handler Jido.Connect.Slack.Handlers.Actions.UpdateMessage
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :ts, :string, required?: true, description: "Slack message timestamp."
        field :text, :string
        field :blocks, {:array, :map}
      end

      output do
        field :channel, :string
        field :ts, :string
        field :message, :map
      end
    end

    action :delete_message do
      id "slack.message.delete"
      resource :message
      verb :delete
      data_classification :message_content
      label "Delete message"

      description """
      Delete a Slack message by channel and timestamp. Slack permits bot tokens
      to delete only messages posted by that bot; user tokens may delete only
      messages that user can delete in Slack.
      """

      handler Jido.Connect.Slack.Handlers.Actions.DeleteMessage
      effect :destructive, confirmation: :always

      access do
        auth [:bot, :user], default: :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :ts, :string, required?: true, description: "Slack message timestamp."
      end

      output do
        field :channel, :string
        field :ts, :string
      end
    end
  end
end
