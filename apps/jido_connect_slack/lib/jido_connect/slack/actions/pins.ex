defmodule Jido.Connect.Slack.Actions.Pins do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_pins do
      id "slack.pin.list"
      resource :pin
      verb :list
      data_classification :workspace_metadata
      label "List pinned items"
      description "List pinned Slack items for a channel."
      handler Jido.Connect.Slack.Handlers.Actions.ListPins

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["pins:read"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
      end

      output do
        field :channel, :string
        field :items, {:array, :map}
      end
    end

    action :add_pin do
      id "slack.pin.add"
      resource :pin
      verb :create
      data_classification :workspace_metadata
      label "Pin message"
      description "Pin a Slack message to a channel by channel and timestamp."
      handler Jido.Connect.Slack.Handlers.Actions.AddPin
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["pins:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :timestamp, :string, required?: true, description: "Slack message timestamp."
      end

      output do
        field :type, :string
        field :channel, :string
        field :timestamp, :string
      end
    end

    action :remove_pin do
      id "slack.pin.remove"
      resource :pin
      verb :delete
      data_classification :workspace_metadata
      label "Unpin message"
      description "Remove a pinned Slack message from a channel by channel and timestamp."
      handler Jido.Connect.Slack.Handlers.Actions.RemovePin
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["pins:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :timestamp, :string, required?: true, description: "Slack message timestamp."
      end

      output do
        field :type, :string
        field :channel, :string
        field :timestamp, :string
      end
    end
  end
end
