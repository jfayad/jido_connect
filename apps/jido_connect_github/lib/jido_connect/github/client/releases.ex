defmodule Jido.Connect.GitHub.Client.Releases do
  @moduledoc "GitHub releases API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.GitHub.Client.{Params, Response, Transport}

  def list_releases(%{repo: repo} = params, access_token)
      when is_binary(repo) and is_binary(access_token) do
    request_params = Params.release_list_params(params)
    req = Transport.request(access_token)

    with {:ok, releases} <-
           req
           |> Req.get(url: "/repos/#{repo}/releases", params: request_params)
           |> Response.handle_release_list_response(),
         {:ok, tags} <-
           req
           |> Req.get(url: "/repos/#{repo}/tags", params: request_params)
           |> Response.handle_tag_list_response() do
      {:ok, %{releases: releases, tags: tags}}
    end
  end

  def create_release(repo, attrs, access_token)
      when is_binary(repo) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/repos/#{repo}/releases", json: Data.compact(attrs))
    |> Response.handle_release_response()
  end

  def upload_release_asset(upload_url, attrs, access_token)
      when is_binary(upload_url) and is_map(attrs) and is_binary(access_token) do
    with {:ok, url} <- Params.release_asset_upload_url(upload_url),
         {:ok, content} <- Params.decode_release_asset_content(attrs) do
      access_token
      |> Transport.request()
      |> Req.post(
        url: url,
        params: Params.release_asset_upload_params(attrs),
        headers: [{"content-type", Map.fetch!(attrs, :content_type)}],
        body: content
      )
      |> Response.handle_release_asset_response()
    end
  end
end
