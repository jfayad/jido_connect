defmodule Jido.Connect.GitHub.Client.Repositories do
  @moduledoc "GitHub repository, branch, commit, and compare API boundary."

  alias Jido.Connect.GitHub.Client.{Params, Response, Transport}

  def list_repositories(params, access_token) when is_map(params) and is_binary(access_token) do
    {url, response_handler} = Params.repository_list_request(params)

    access_token
    |> Transport.request()
    |> Req.get(
      url: url,
      params: Params.repository_list_params(params)
    )
    |> response_handler.()
  end

  def get_repository(owner, name, access_token)
      when is_binary(owner) and is_binary(name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/repos/#{owner}/#{name}")
    |> Response.handle_repository_response()
  end

  def list_branches(%{repo: repo} = params, access_token)
      when is_binary(repo) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/branches",
      params: Params.branch_list_params(params)
    )
    |> Response.handle_branch_list_response()
  end

  def create_branch(repo, attrs, access_token)
      when is_binary(repo) and is_map(attrs) and is_binary(access_token) do
    req = Transport.request(access_token)

    with {:ok, sha} <- Params.branch_source_sha(req, repo, attrs) do
      req
      |> Req.post(
        url: "/repos/#{repo}/git/refs",
        json: %{ref: "refs/heads/#{Map.fetch!(attrs, :branch)}", sha: sha}
      )
      |> Response.handle_ref_create_response()
    end
  end

  def list_commits(%{repo: repo} = params, access_token)
      when is_binary(repo) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/commits",
      params: Params.commit_list_params(params)
    )
    |> Response.handle_commit_list_response()
  end

  def compare_refs(%{repo: repo, base: base, head: head} = params, access_token)
      when is_binary(repo) and is_binary(base) and is_binary(head) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/compare/#{Params.encode_ref(base)}...#{Params.encode_ref(head)}",
      params: Params.compare_refs_params(params)
    )
    |> Response.handle_compare_refs_response()
  end
end
