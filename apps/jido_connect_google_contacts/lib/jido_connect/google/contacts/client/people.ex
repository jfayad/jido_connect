defmodule Jido.Connect.Google.Contacts.Client.People do
  @moduledoc "Google People API boundary for person reads and search."

  alias Jido.Connect.Google.Contacts.Client.{Params, Response, Transport}

  def list_people(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/#{resource_path(resource_name)}/connections",
      params: Params.list_people_params(params)
    )
    |> Response.handle_person_list_response()
  end

  def get_person(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/#{resource_path(resource_name)}",
      params: Params.get_person_params(params)
    )
    |> Response.handle_person_response()
  end

  def search_people(%{query: query} = params, access_token)
      when is_binary(query) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/people:searchContacts",
      params: Params.search_people_params(params)
    )
    |> Response.handle_person_search_response()
  end

  defp resource_path(resource_name) do
    resource_name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
