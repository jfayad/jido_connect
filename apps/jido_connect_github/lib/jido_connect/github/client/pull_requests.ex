defmodule Jido.Connect.GitHub.Client.PullRequests do
  @moduledoc "GitHub pull request API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.GitHub.Client.{Params, Response, Transport}

  def list_pull_requests(%{repo: repo} = params, access_token)
      when is_binary(repo) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/pulls",
      params: Params.pull_request_list_params(params)
    )
    |> Response.handle_pull_request_list_response()
  end

  def get_pull_request(repo, pull_number, access_token)
      when is_binary(repo) and is_integer(pull_number) and is_binary(access_token) do
    req = Transport.request(access_token)

    with {:ok, pull_request} <-
           req
           |> Req.get(url: "/repos/#{repo}/pulls/#{pull_number}")
           |> Response.handle_pull_request_response(),
         {:ok, issue} <-
           req
           |> Req.get(url: "/repos/#{repo}/issues/#{pull_number}")
           |> Response.handle_issue_context_response() do
      {:ok, Map.put(pull_request, :issue, issue)}
    end
  end

  def list_pull_request_files(%{repo: repo, pull_number: pull_number} = params, access_token)
      when is_binary(repo) and is_integer(pull_number) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/pulls/#{pull_number}/files",
      params: Params.pull_request_file_list_params(params)
    )
    |> Response.handle_pull_request_file_list_response()
  end

  def create_pull_request(repo, attrs, access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/repos/#{repo}/pulls", json: attrs)
    |> Response.handle_pull_request_response()
  end

  def update_pull_request(repo, pull_number, attrs, access_token)
      when is_integer(pull_number) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(url: "/repos/#{repo}/pulls/#{pull_number}", json: attrs)
    |> Response.handle_pull_request_response()
  end

  def request_pull_request_reviewers(repo, pull_number, attrs, access_token)
      when is_integer(pull_number) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/repos/#{repo}/pulls/#{pull_number}/requested_reviewers",
      json: Data.compact(attrs)
    )
    |> Response.handle_pull_request_reviewers_response()
  end

  def create_pull_request_review_comment(repo, pull_number, attrs, access_token)
      when is_binary(repo) and is_integer(pull_number) and is_map(attrs) and
             is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/repos/#{repo}/pulls/#{pull_number}/comments",
      json: Data.compact(attrs)
    )
    |> Response.handle_pull_request_review_comment_response()
  end

  def merge_pull_request(repo, pull_number, attrs, access_token)
      when is_integer(pull_number) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(url: "/repos/#{repo}/pulls/#{pull_number}/merge", json: attrs)
    |> Response.handle_pull_request_merge_response()
  end

  def list_updated_pull_requests(repo, checkpoint, access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/search/issues",
      params: [
        q: Params.updated_pull_request_query(repo, checkpoint),
        sort: "updated",
        order: "asc",
        per_page: 100
      ]
    )
    |> Response.handle_updated_pull_request_list_response()
  end
end
