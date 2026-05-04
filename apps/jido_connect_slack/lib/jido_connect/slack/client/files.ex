defmodule Jido.Connect.Slack.Client.Files do
  @moduledoc "Slack file API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Client.{Params, Response, Transport}

  def search_files(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/search.files", params: Params.search_params(params))
    |> Response.handle_search_files_response()
  end

  def upload_file(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    content = Data.get(attrs, :content, "")

    with {:ok, upload} <-
           access_token
           |> Transport.request()
           |> Req.post(
             url: "/files.getUploadURLExternal",
             json: Params.upload_url_params(attrs, content)
           )
           |> Response.handle_upload_url_response(),
         {:ok, _response} <- Transport.post_file_content(Data.get(upload, :upload_url), content),
         {:ok, complete} <-
           access_token
           |> Transport.request()
           |> Req.post(
             url: "/files.completeUploadExternal",
             json: Params.complete_upload_params(attrs, upload)
           )
           |> Response.handle_complete_upload_response(upload) do
      {:ok, complete}
    end
  end

  def share_file(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/files.completeUploadExternal",
      json: Params.share_file_params(attrs)
    )
    |> Response.handle_share_file_response(attrs)
  end

  def delete_file(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/files.delete", json: Params.delete_file_params(attrs))
    |> Response.handle_delete_file_response(attrs)
  end
end
