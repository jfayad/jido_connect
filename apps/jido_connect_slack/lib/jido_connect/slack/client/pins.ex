defmodule Jido.Connect.Slack.Client.Pins do
  @moduledoc "Slack pins API boundary."

  alias Jido.Connect.Slack.Client.Rest

  defdelegate list_pins(params, access_token), to: Rest
  defdelegate add_pin(attrs, access_token), to: Rest
  defdelegate remove_pin(attrs, access_token), to: Rest
end
