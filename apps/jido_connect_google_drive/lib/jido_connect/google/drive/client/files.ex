defmodule Jido.Connect.Google.Drive.Client.Files do
  @moduledoc "Google Drive files API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def list_files(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/v3/files", params: Params.list_files_params(params))
    |> Response.handle_file_list_response()
  end

  def get_file(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{URI.encode(file_id, &URI.char_unreserved?/1)}",
      params: Params.get_file_params(params)
    )
    |> Response.handle_file_response()
  end
end
