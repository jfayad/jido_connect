defmodule Jido.Connect.Google.Drive.Client.Permissions do
  @moduledoc "Google Drive permissions API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def list_permissions(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/permissions",
      params: Params.list_permissions_params(params)
    )
    |> Response.handle_permission_list_response()
  end

  def create_permission(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/files/#{encode_id(file_id)}/permissions",
      params: Params.create_permission_params(params),
      json: Params.permission_body(params)
    )
    |> Response.handle_permission_response()
  end

  defp encode_id(file_id), do: URI.encode(file_id, &URI.char_unreserved?/1)
end
