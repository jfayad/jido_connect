defmodule Jido.Connect.GitHub.Client do
  @moduledoc """
  Minimal GitHub REST client for live demos and integration tests.

  The public functions match the client boundary used by the GitHub action and
  poll handlers. Tests can keep injecting a fake module; demos can inject this
  module with a real token lease.
  """

  alias Jido.Connect.{Data, Http, Polling}

  @api_version "2022-11-28"

  def list_issues(repo, state, access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(
      url: "/repos/#{repo}/issues",
      params: [state: state, sort: "created", direction: "desc", per_page: 100]
    )
    |> handle_list_response()
  end

  def create_issue(repo, attrs, access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/repos/#{repo}/issues", json: attrs)
    |> handle_issue_response()
  end

  def close_issue(repo, number, access_token)
      when is_integer(number) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.patch(
      url: "/repos/#{repo}/issues/#{number}",
      json: %{state: "closed", state_reason: "completed"}
    )
    |> handle_issue_response()
  end

  def list_new_issues(repo, checkpoint, access_token) when is_binary(access_token) do
    params =
      [
        state: "all",
        sort: "updated",
        direction: "asc",
        per_page: 100
      ]
      |> Polling.put_checkpoint_param(:since, checkpoint)

    access_token
    |> request()
    |> Req.get(url: "/repos/#{repo}/issues", params: params)
    |> handle_list_response()
  end

  def fetch_authenticated_user(access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/user")
    |> handle_map_response()
  end

  def fetch_installation(installation_id, access_token) when is_integer(installation_id) do
    access_token
    |> request()
    |> Req.get(url: "/app/installations/#{installation_id}")
    |> handle_map_response()
  end

  defp request(access_token) do
    Http.bearer_request(
      base_url(),
      access_token,
      headers: [
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", @api_version}
      ],
      req_options: Application.get_env(:jido_connect_github, :github_req_options, [])
    )
  end

  defp base_url do
    Application.get_env(:jido_connect_github, :github_api_base_url, "https://api.github.com")
  end

  defp handle_list_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, Enum.map(body, &normalize_issue/1)}
  end

  defp handle_list_response(response), do: handle_error_response(response)

  defp handle_issue_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, normalize_issue(body)}
  end

  defp handle_issue_response(response), do: handle_error_response(response)

  defp handle_map_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_map_response(response), do: handle_error_response(response)

  defp handle_error_response(response),
    do: Http.provider_error(response, provider: :github, message: "GitHub API request failed")

  defp normalize_issue(issue) when is_map(issue) do
    %{
      number: Data.get(issue, "number"),
      url: Data.get(issue, "html_url") || Data.get(issue, "url"),
      title: Data.get(issue, "title"),
      state: Data.get(issue, "state"),
      updated_at: Data.get(issue, "updated_at")
    }
  end
end
