defmodule Jido.Connect.GitHub.Client.Search do
  @moduledoc "GitHub search API boundary."

  alias Jido.Connect.GitHub.Client.{Params, Response, Transport}

  def search_issues(%{q: query} = params, access_token)
      when is_binary(query) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/search/issues", params: Params.search_issue_params(params))
    |> Response.handle_search_issue_response()
  end

  def search_repositories(%{q: query} = params, access_token)
      when is_binary(query) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/search/repositories", params: Params.search_repository_params(params))
    |> Response.handle_search_repository_response()
  end
end
