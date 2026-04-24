defmodule Jido.Connect.GitHub.Client do
  @moduledoc """
  Minimal GitHub REST client for live demos and integration tests.

  The public functions match the client boundary used by the GitHub action and
  poll handlers. Tests can keep injecting a fake module; demos can inject this
  module with a real token lease.
  """

  @api_version "2022-11-28"

  def list_issues(repo, state, access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/repos/#{repo}/issues", params: [state: state])
    |> handle_list_response()
  end

  def create_issue(repo, attrs, access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/repos/#{repo}/issues", json: attrs)
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
      |> maybe_since(checkpoint)

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
    Req.new(
      base_url: base_url(),
      headers: [
        {"accept", "application/vnd.github+json"},
        {"authorization", "Bearer #{access_token}"},
        {"x-github-api-version", @api_version},
        {"user-agent", "jido-connect"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_github, :github_req_options, []))
  end

  defp base_url do
    Application.get_env(:jido_connect_github, :github_api_base_url, "https://api.github.com")
  end

  defp maybe_since(params, nil), do: params
  defp maybe_since(params, ""), do: params
  defp maybe_since(params, checkpoint), do: Keyword.put(params, :since, checkpoint)

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

  defp handle_error_response({:ok, %{status: status, body: body}}) do
    {:error, {:github_http_error, status, error_message(body)}}
  end

  defp handle_error_response({:error, reason}), do: {:error, reason}

  defp normalize_issue(issue) when is_map(issue) do
    %{
      number: get(issue, "number"),
      url: get(issue, "html_url") || get(issue, "url"),
      title: get(issue, "title"),
      state: get(issue, "state"),
      updated_at: get(issue, "updated_at")
    }
  end

  defp get(map, key), do: Map.get(map, key) || Map.get(map, String.to_atom(key))

  defp error_message(%{"message" => message}), do: message
  defp error_message(%{message: message}), do: message
  defp error_message(body), do: body
end
