defmodule Jido.Connect.Slack.Client.Identity do
  @moduledoc "Slack auth and team metadata API boundary."

  alias Jido.Connect.Slack.Client.Rest

  defdelegate auth_test(access_token), to: Rest
  defdelegate team_info(params, access_token), to: Rest
end
