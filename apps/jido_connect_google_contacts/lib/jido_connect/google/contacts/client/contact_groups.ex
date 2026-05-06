defmodule Jido.Connect.Google.Contacts.Client.ContactGroups do
  @moduledoc "Google People API boundary for contact group reads and mutations."

  alias Jido.Connect.Google.Contacts.Client.{Params, Response, Transport}

  def list_contact_groups(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/contactGroups",
      params: Params.list_contact_groups_params(params)
    )
    |> Response.handle_contact_group_list_response()
  end

  def create_contact_group(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/contactGroups",
      params: Params.create_contact_group_params(params),
      json: Params.contact_group_body(params)
    )
    |> Response.handle_contact_group_response()
  end

  def update_contact_group(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/v1/#{resource_path(resource_name)}",
      params: Params.update_contact_group_params(params),
      json: Params.contact_group_body(params)
    )
    |> Response.handle_contact_group_response()
  end

  defp resource_path(resource_name) do
    resource_name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
