defmodule Jido.Connect.GitHub.Client.Identity do
  @moduledoc "GitHub authenticated-user API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate fetch_authenticated_user(access_token), to: Rest
end
