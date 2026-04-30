defmodule Jido.Connect.GitHub.Client.Search do
  @moduledoc "GitHub search API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate search_issues(params, access_token), to: Rest
  defdelegate search_repositories(params, access_token), to: Rest
end
