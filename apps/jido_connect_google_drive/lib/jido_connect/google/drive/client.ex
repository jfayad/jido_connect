defmodule Jido.Connect.Google.Drive.Client do
  @moduledoc "Google Drive API client facade."

  alias Jido.Connect.Google.Drive.Client.Files

  defdelegate list_files(params, access_token), to: Files
  defdelegate get_file(params, access_token), to: Files
end
