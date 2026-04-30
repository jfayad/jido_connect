defmodule Jido.Connect.Slack.Actions.Pins do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
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
  end
end
