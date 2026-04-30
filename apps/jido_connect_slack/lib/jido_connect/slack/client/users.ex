defmodule Jido.Connect.Slack.Client.Users do
  @moduledoc "Slack users API boundary."

  alias Jido.Connect.Slack.Client.Rest

  defdelegate list_users(params, access_token), to: Rest
  defdelegate user_info(params, access_token), to: Rest
  defdelegate lookup_user_by_email(params, access_token), to: Rest
end
