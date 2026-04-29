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

  def list_pull_requests(%{repo: repo} = params, access_token)
      when is_binary(repo) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(
      url: "/repos/#{repo}/pulls",
      params: pull_request_list_params(params)
    )
    |> handle_pull_request_list_response()
  end

  def search_issues(%{q: query} = params, access_token)
      when is_binary(query) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/search/issues", params: search_issue_params(params))
    |> handle_search_issue_response()
  end

  def list_workflow_runs(%{repo: repo} = params, access_token)
      when is_binary(repo) and is_binary(access_token) do
    {url, request_params} = workflow_run_list_request(repo, params)

    access_token
    |> request()
    |> Req.get(url: url, params: request_params)
    |> handle_workflow_run_list_response()
  end

  def dispatch_workflow(repo, workflow, attrs, access_token)
      when is_binary(repo) and is_binary(workflow) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/repos/#{repo}/actions/workflows/#{workflow}/dispatches", json: attrs)
    |> handle_workflow_dispatch_response()
  end

  def get_pull_request(repo, pull_number, access_token)
      when is_binary(repo) and is_integer(pull_number) and is_binary(access_token) do
    with {:ok, pull_request} <-
           access_token
           |> request()
           |> Req.get(url: "/repos/#{repo}/pulls/#{pull_number}")
           |> handle_pull_request_response(),
         {:ok, issue} <-
           access_token
           |> request()
           |> Req.get(url: "/repos/#{repo}/issues/#{pull_number}")
           |> handle_issue_context_response() do
      {:ok, Map.put(pull_request, :issue, issue)}
    end
  end

  def create_pull_request(repo, attrs, access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/repos/#{repo}/pulls", json: attrs)
    |> handle_pull_request_response()
  end

  def update_pull_request(repo, pull_number, attrs, access_token)
      when is_integer(pull_number) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.patch(url: "/repos/#{repo}/pulls/#{pull_number}", json: attrs)
    |> handle_pull_request_response()
  end

  def merge_pull_request(repo, pull_number, attrs, access_token)
      when is_integer(pull_number) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.put(url: "/repos/#{repo}/pulls/#{pull_number}/merge", json: attrs)
    |> handle_pull_request_merge_response()
  end

  def create_issue(repo, attrs, access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/repos/#{repo}/issues", json: attrs)
    |> handle_issue_response()
  end

  def update_issue(repo, issue_number, attrs, access_token)
      when is_integer(issue_number) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.patch(url: "/repos/#{repo}/issues/#{issue_number}", json: attrs)
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

  defp handle_pull_request_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_pull_request/1)}
  end

  defp handle_pull_request_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub pull request list response was invalid", body)
  end

  defp handle_pull_request_list_response(response), do: handle_error_response(response)

  defp handle_search_issue_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    case Data.get(body, "items") do
      items when is_list(items) ->
        {:ok,
         %{
           results: Enum.map(items, &normalize_search_issue/1),
           total_count: Data.get(body, "total_count")
         }}

      _other ->
        invalid_success_response("GitHub issue search response was invalid", body)
    end
  end

  defp handle_search_issue_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub issue search response was invalid", body)
  end

  defp handle_search_issue_response(response), do: handle_error_response(response)

  defp handle_pull_request_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    {:ok, normalize_pull_request_details(body)}
  end

  defp handle_pull_request_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub pull request response was invalid", body)
  end

  defp handle_pull_request_response(response), do: handle_error_response(response)

  defp handle_workflow_run_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    case Data.get(body, "workflow_runs") do
      workflow_runs when is_list(workflow_runs) ->
        {:ok,
         %{
           workflow_runs: Enum.map(workflow_runs, &normalize_workflow_run/1),
           total_count: Data.get(body, "total_count")
         }}

      _other ->
        invalid_success_response("GitHub workflow run list response was invalid", body)
    end
  end

  defp handle_workflow_run_list_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub workflow run list response was invalid", body)
  end

  defp handle_workflow_run_list_response(response), do: handle_error_response(response)

  defp handle_workflow_dispatch_response({:ok, %{status: 204}}), do: {:ok, %{dispatched: true}}

  defp handle_workflow_dispatch_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub workflow dispatch response was invalid", body)
  end

  defp handle_workflow_dispatch_response(response), do: handle_error_response(response)

  defp handle_pull_request_merge_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    {:ok, normalize_pull_request_merge(body)}
  end

  defp handle_pull_request_merge_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub pull request merge response was invalid", body)
  end

  defp handle_pull_request_merge_response(response), do: handle_error_response(response)

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

  defp handle_issue_context_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    {:ok, normalize_issue_context(body)}
  end

  defp handle_issue_context_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    invalid_success_response("GitHub issue context response was invalid", body)
  end

  defp handle_issue_context_response(response), do: handle_error_response(response)

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

  defp normalize_pull_request(pull_request) when is_map(pull_request) do
    %{
      number: Data.get(pull_request, "number"),
      url: Data.get(pull_request, "html_url") || Data.get(pull_request, "url"),
      title: Data.get(pull_request, "title"),
      state: Data.get(pull_request, "state"),
      head: normalize_pull_request_ref(Data.get(pull_request, "head")),
      base: normalize_pull_request_ref(Data.get(pull_request, "base")),
      updated_at: Data.get(pull_request, "updated_at")
    }
  end

  defp normalize_search_issue(issue) when is_map(issue) do
    %{
      type: search_issue_type(issue),
      number: Data.get(issue, "number"),
      url: Data.get(issue, "html_url") || Data.get(issue, "url"),
      title: Data.get(issue, "title"),
      state: Data.get(issue, "state"),
      user: normalize_user(Data.get(issue, "user")),
      labels: normalize_labels(Data.get(issue, "labels")),
      comments: Data.get(issue, "comments"),
      created_at: Data.get(issue, "created_at"),
      updated_at: Data.get(issue, "updated_at")
    }
    |> Data.compact()
  end

  defp search_issue_type(issue) do
    if Data.get(issue, "pull_request"), do: :pull_request, else: :issue
  end

  defp normalize_pull_request_details(pull_request) when is_map(pull_request) do
    %{
      number: Data.get(pull_request, "number"),
      url: Data.get(pull_request, "html_url") || Data.get(pull_request, "url"),
      title: Data.get(pull_request, "title"),
      state: Data.get(pull_request, "state"),
      body: Data.get(pull_request, "body"),
      draft: Data.get(pull_request, "draft"),
      maintainer_can_modify: Data.get(pull_request, "maintainer_can_modify"),
      merged: Data.get(pull_request, "merged"),
      mergeable: Data.get(pull_request, "mergeable"),
      mergeable_state: Data.get(pull_request, "mergeable_state"),
      merge_commit_sha: Data.get(pull_request, "merge_commit_sha"),
      commits: Data.get(pull_request, "commits"),
      additions: Data.get(pull_request, "additions"),
      deletions: Data.get(pull_request, "deletions"),
      changed_files: Data.get(pull_request, "changed_files"),
      head: normalize_pull_request_ref(Data.get(pull_request, "head")),
      base: normalize_pull_request_ref(Data.get(pull_request, "base")),
      user: normalize_user(Data.get(pull_request, "user")),
      labels: normalize_labels(Data.get(pull_request, "labels")),
      updated_at: Data.get(pull_request, "updated_at")
    }
    |> Data.compact()
  end

  defp normalize_comment(comment) when is_map(comment) do
    %{
      id: Data.get(comment, "id"),
      url: Data.get(comment, "html_url") || Data.get(comment, "url"),
      body: Data.get(comment, "body")
    }
  end

  defp normalize_pull_request_merge(result) when is_map(result) do
    %{
      sha: Data.get(result, "sha"),
      merged: Data.get(result, "merged"),
      message: Data.get(result, "message")
    }
    |> Data.compact()
  end

  defp normalize_workflow_run(workflow_run) when is_map(workflow_run) do
    %{
      id: Data.get(workflow_run, "id"),
      name: Data.get(workflow_run, "name"),
      number: Data.get(workflow_run, "run_number"),
      status: Data.get(workflow_run, "status"),
      conclusion: Data.get(workflow_run, "conclusion"),
      event: Data.get(workflow_run, "event"),
      branch: Data.get(workflow_run, "head_branch"),
      sha: Data.get(workflow_run, "head_sha"),
      workflow_id: Data.get(workflow_run, "workflow_id"),
      url: Data.get(workflow_run, "html_url") || Data.get(workflow_run, "url"),
      created_at: Data.get(workflow_run, "created_at"),
      updated_at: Data.get(workflow_run, "updated_at")
    }
    |> Data.compact()
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

  defp normalize_pull_request_ref(ref) when is_map(ref) do
    %{
      label: Data.get(ref, "label"),
      ref: Data.get(ref, "ref"),
      sha: Data.get(ref, "sha"),
      repo: normalize_pull_request_ref_repo(Data.get(ref, "repo"))
    }
    |> Data.compact()
  end

  defp normalize_pull_request_ref(_ref), do: nil

  defp normalize_pull_request_ref_repo(repo) when is_map(repo) do
    %{
      id: Data.get(repo, "id"),
      name: Data.get(repo, "name"),
      full_name: Data.get(repo, "full_name"),
      url: Data.get(repo, "html_url") || Data.get(repo, "url")
    }
    |> Data.compact()
  end

  defp normalize_pull_request_ref_repo(_repo), do: nil

  defp normalize_issue_context(issue) when is_map(issue) do
    %{
      number: Data.get(issue, "number"),
      url: Data.get(issue, "html_url") || Data.get(issue, "url"),
      title: Data.get(issue, "title"),
      state: Data.get(issue, "state"),
      labels: normalize_labels(Data.get(issue, "labels")),
      assignees: normalize_users(Data.get(issue, "assignees")),
      milestone: normalize_milestone(Data.get(issue, "milestone"))
    }
    |> Data.compact()
  end

  defp normalize_labels(labels) when is_list(labels) do
    Enum.map(labels, fn label ->
      %{
        name: Data.get(label, "name"),
        color: Data.get(label, "color"),
        description: Data.get(label, "description")
      }
      |> Data.compact()
    end)
  end

  defp normalize_labels(_labels), do: []

  defp normalize_users(users) when is_list(users), do: Enum.map(users, &normalize_user/1)
  defp normalize_users(_users), do: []

  defp normalize_user(user) when is_map(user) do
    %{
      login: Data.get(user, "login"),
      id: Data.get(user, "id"),
      type: Data.get(user, "type"),
      url: Data.get(user, "html_url") || Data.get(user, "url")
    }
    |> Data.compact()
  end

  defp normalize_user(_user), do: nil

  defp normalize_milestone(milestone) when is_map(milestone) do
    %{
      number: Data.get(milestone, "number"),
      title: Data.get(milestone, "title"),
      state: Data.get(milestone, "state"),
      description: Data.get(milestone, "description"),
      due_on: Data.get(milestone, "due_on")
    }
    |> Data.compact()
  end

  defp normalize_milestone(_milestone), do: nil

  defp repository_list_params(params) do
    [
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
  end

  defp pull_request_list_params(params) do
    [
      state: Map.get(params, :state, "open"),
      head: Map.get(params, :head),
      base: Map.get(params, :base),
      sort: Map.get(params, :sort, "created"),
      direction: Map.get(params, :direction, "desc"),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp search_issue_params(params) do
    [
      q: Map.fetch!(params, :q),
      sort: Map.get(params, :sort, "updated"),
      order: Map.get(params, :direction, "desc"),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp workflow_run_list_params(params) do
    [
      branch: Map.get(params, :branch),
      status: Map.get(params, :status),
      event: Map.get(params, :event),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp repository_list_request(%{auth_profile: :installation}),
    do: {"/installation/repositories", &handle_repository_list_response/1}

  defp repository_list_request(_params),
    do: {"/user/repos", &handle_user_repository_list_response/1}

  defp workflow_run_list_request(repo, %{workflow: workflow} = params) when is_binary(workflow),
    do: {"/repos/#{repo}/actions/workflows/#{workflow}/runs", workflow_run_list_params(params)}

  defp workflow_run_list_request(repo, params),
    do: {"/repos/#{repo}/actions/runs", workflow_run_list_params(params)}

  defp invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :github,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
