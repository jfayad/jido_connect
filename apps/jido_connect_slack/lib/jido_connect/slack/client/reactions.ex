defmodule Jido.Connect.Slack.Client.Reactions do
  @moduledoc "Slack reactions API boundary."

  alias Jido.Connect.Slack.Client.Rest

  defdelegate add_reaction(attrs, access_token), to: Rest
  defdelegate remove_reaction(attrs, access_token), to: Rest
  defdelegate get_reactions(params, access_token), to: Rest
end
