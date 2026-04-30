defmodule Jido.Connect.GitHub.Client.Releases do
  @moduledoc "GitHub releases API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate list_releases(params, access_token), to: Rest
  defdelegate create_release(repo, attrs, access_token), to: Rest
  defdelegate upload_release_asset(upload_url, attrs, access_token), to: Rest
end
