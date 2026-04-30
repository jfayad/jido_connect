defmodule Jido.Connect.GitHub.Client.Installations do
  @moduledoc "GitHub installation metadata API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate fetch_installation(installation_id, access_token), to: Rest
end
