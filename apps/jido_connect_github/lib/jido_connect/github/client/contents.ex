defmodule Jido.Connect.GitHub.Client.Contents do
  @moduledoc "GitHub repository contents API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate read_file(repo, path, ref, access_token), to: Rest
  defdelegate update_file(repo, path, attrs, access_token), to: Rest
end
