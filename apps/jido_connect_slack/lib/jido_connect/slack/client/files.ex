defmodule Jido.Connect.Slack.Client.Files do
  @moduledoc "Slack file API boundary."

  alias Jido.Connect.Slack.Client.Rest

  defdelegate search_files(params, access_token), to: Rest
  defdelegate upload_file(attrs, access_token), to: Rest
  defdelegate share_file(attrs, access_token), to: Rest
  defdelegate delete_file(attrs, access_token), to: Rest
end
