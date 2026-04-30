defmodule Jido.Connect.Slack.Client.Conversations do
  @moduledoc "Slack Conversations API boundary."

  alias Jido.Connect.Slack.Client.Rest

  defdelegate list_channels(params, access_token), to: Rest
  defdelegate get_conversation_info(params, access_token), to: Rest
  defdelegate create_channel(params, access_token), to: Rest
  defdelegate archive_conversation(params, access_token), to: Rest
  defdelegate unarchive_conversation(params, access_token), to: Rest
  defdelegate rename_conversation(params, access_token), to: Rest
  defdelegate invite_conversation(params, access_token), to: Rest
  defdelegate kick_conversation(params, access_token), to: Rest
  defdelegate open_conversation(params, access_token), to: Rest
  defdelegate list_conversation_members(params, access_token), to: Rest
end
