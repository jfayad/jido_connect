defmodule Jido.Connect.GitHub.Client do
  @moduledoc """
  Minimal GitHub REST client for live demos and integration tests.

  The public functions match the client boundary used by the GitHub action and
  poll handlers. Tests can keep injecting a fake module; demos can inject this
  module with a real token lease.
  """

  alias Jido.Connect.{Data, Error, Http, Polling}

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

  def list_repositories(params, access_token) when is_map(params) and is_binary(access_token) do
    {url, response_handler} = repository_list_request(params)

    access_token
    |> request()
    |> Req.get(
      url: url,
      params: repository_list_params(params)
    )
    |> response_handler.()
  end

  def create_issue(repo, attrs, access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/repos/#{repo}/issues", json: attrs)
    |> handle_issue_response()
  end

  def create_issue_comment(repo, issue_number, body, access_token)
      when is_integer(issue_number) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/repos/#{repo}/issues/#{issue_number}/comments", json: %{body: body})
    |> handle_comment_response()
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

  defp handle_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_issue/1)}
  end

  defp handle_list_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    invalid_success_response("GitHub list issues response was invalid", body)
  end

  defp handle_list_response(response), do: handle_error_response(response)

  defp handle_repository_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    case Data.get(body, "repositories") do
      repositories when is_list(repositories) ->
        {:ok,
         %{
           repositories: Enum.map(repositories, &normalize_repository/1),
           total_count: Data.get(body, "total_count")
         }}

      _other ->
        invalid_success_response("GitHub repository list response was invalid", body)
    end
  end

  defp handle_repository_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub repository list response was invalid", body)
  end

  defp handle_repository_list_response(response), do: handle_error_response(response)

  defp handle_user_repository_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_list(body) do
    {:ok,
     %{
       repositories: Enum.map(body, &normalize_repository/1),
       total_count: length(body)
     }}
  end

  defp handle_user_repository_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub repository list response was invalid", body)
  end

  defp handle_user_repository_list_response(response), do: handle_error_response(response)

  defp handle_issue_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    {:ok, normalize_issue(body)}
  end

  defp handle_issue_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    invalid_success_response("GitHub issue response was invalid", body)
  end

  defp handle_issue_response(response), do: handle_error_response(response)

  defp handle_comment_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    {:ok, normalize_comment(body)}
  end

  defp handle_comment_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    invalid_success_response("GitHub comment response was invalid", body)
  end

  defp handle_comment_response(response), do: handle_error_response(response)

  defp handle_map_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  defp handle_map_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    invalid_success_response("GitHub response was invalid", body)
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

  defp normalize_repository(repository) when is_map(repository) do
    %{
      id: Data.get(repository, "id"),
      name: Data.get(repository, "name"),
      full_name: Data.get(repository, "full_name"),
      owner: normalize_repository_owner(Data.get(repository, "owner")),
      private: Data.get(repository, "private"),
      default_branch: Data.get(repository, "default_branch"),
      url: Data.get(repository, "html_url") || Data.get(repository, "url")
    }
  end

  defp normalize_comment(comment) when is_map(comment) do
    %{
      id: Data.get(comment, "id"),
      url: Data.get(comment, "html_url") || Data.get(comment, "url"),
      body: Data.get(comment, "body")
    }
  end

  defp normalize_repository_owner(owner) when is_map(owner) do
    %{
      login: Data.get(owner, "login"),
      id: Data.get(owner, "id"),
      type: Data.get(owner, "type"),
      url: Data.get(owner, "html_url") || Data.get(owner, "url")
    }
    |> Data.compact()
  end

  defp normalize_repository_owner(_owner), do: nil

  defp repository_list_params(params) do
    [
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
  end

  defp repository_list_request(%{auth_profile: :installation}),
    do: {"/installation/repositories", &handle_repository_list_response/1}

  defp repository_list_request(_params),
    do: {"/user/repos", &handle_user_repository_list_response/1}

  defp invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :github,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
