defmodule Jido.Connect.Slack.Client.Messages do
  @moduledoc "Slack message and message-search API boundary."

  alias Jido.Connect.Slack.Client.Rest

  defdelegate post_message(attrs, access_token), to: Rest
  defdelegate post_ephemeral(attrs, access_token), to: Rest
  defdelegate schedule_message(attrs, access_token), to: Rest
  defdelegate delete_scheduled_message(attrs, access_token), to: Rest
  defdelegate update_message(attrs, access_token), to: Rest
  defdelegate delete_message(attrs, access_token), to: Rest
  defdelegate get_thread_replies(params, access_token), to: Rest
  defdelegate search_messages(params, access_token), to: Rest
end
