defmodule Jido.Connect.GitHub.Client.Contents do
  @moduledoc "GitHub repository contents API boundary."

  alias Jido.Connect.GitHub.Client.{Params, Response, Transport}

  def read_file(repo, path, ref, access_token)
      when is_binary(repo) and is_binary(path) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/contents/#{Params.encode_path(path)}",
      params: Params.file_content_params(ref)
    )
    |> Response.handle_file_content_response()
  end

  def update_file(repo, path, attrs, access_token)
      when is_binary(repo) and is_binary(path) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/repos/#{repo}/contents/#{Params.encode_path(path)}",
      json: Params.file_update_payload(attrs)
    )
    |> Response.handle_file_update_response()
  end
end
