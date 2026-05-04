defmodule Jido.Connect.GitHub.Client.Params do
  @moduledoc "GitHub REST request parameter and payload helpers."

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.GitHub.Client.{Response, Transport}

  def repository_list_params(params) do
    [
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
  end

  def branch_list_params(params) do
    [
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
  end

  def branch_source_sha(_req, _repo, %{source_sha: sha}) when is_binary(sha), do: {:ok, sha}

  def branch_source_sha(req, repo, %{source_ref: ref}) when is_binary(ref) do
    req
    |> Req.get(url: "/repos/#{repo}/git/ref/#{encode_path(git_ref_path(ref))}")
    |> Response.handle_ref_fetch_response()
    |> case do
      {:ok, %{sha: sha}} when is_binary(sha) ->
        {:ok, sha}

      {:ok, ref} ->
        Transport.invalid_success_response("GitHub source ref response was invalid", ref)

      {:error, error} ->
        {:error, error}
    end
  end

  def git_ref_path("refs/" <> ref), do: ref

  def git_ref_path(ref) do
    if String.contains?(ref, "/") do
      ref
    else
      "heads/#{ref}"
    end
  end

  def commit_list_params(params) do
    [
      sha: Map.get(params, :ref),
      path: Map.get(params, :path),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def compare_refs_params(params) do
    [
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
  end

  def file_content_params(ref) when is_binary(ref), do: [ref: ref]
  def file_content_params(_ref), do: []

  def file_update_payload(attrs) do
    attrs
    |> Map.put(:content, Base.encode64(Map.fetch!(attrs, :content)))
    |> Data.compact()
  end

  def encode_path(path) do
    path
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &char_unreserved?/1) end)
    |> Enum.join("/")
  end

  def encode_ref(ref), do: URI.encode(ref, &char_unreserved?/1)

  def char_unreserved?(character), do: URI.char_unreserved?(character)

  def ref_already_exists?(body) when is_map(body) do
    message = body |> Data.get("message", "") |> to_string() |> String.downcase()
    errors = Data.get(body, "errors", [])

    String.contains?(message, "reference already exists") or
      Enum.any?(List.wrap(errors), fn error ->
        error_message = error |> Data.get("message", "") |> to_string() |> String.downcase()
        code = error |> Data.get("code", "") |> to_string() |> String.downcase()

        String.contains?(error_message, "reference already exists") or code == "already_exists"
      end)
  end

  def ref_already_exists?(_body), do: false

  def pull_request_list_params(params) do
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

  def updated_pull_request_query(repo, checkpoint) when checkpoint in [nil, ""] do
    "repo:#{repo} is:pr"
  end

  def updated_pull_request_query(repo, checkpoint) do
    "repo:#{repo} is:pr updated:>=#{checkpoint}"
  end

  def search_issue_params(params) do
    [
      q: Map.fetch!(params, :q),
      sort: Map.get(params, :sort, "updated"),
      order: Map.get(params, :direction, "desc"),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def search_repository_params(params) do
    [
      q: Map.fetch!(params, :q),
      sort: Map.get(params, :sort, "updated"),
      order: Map.get(params, :direction, "desc"),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def pull_request_file_list_params(params) do
    [
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def workflow_run_list_params(params) do
    [
      branch: Map.get(params, :branch),
      status: Map.get(params, :status),
      event: Map.get(params, :event),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def release_list_params(params) do
    [
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def release_asset_upload_url(upload_url) do
    url = String.replace(upload_url, ~r/\{\?.*\}\z/, "")
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] and is_binary(uri.host) do
      {:ok, url}
    else
      {:error,
       Error.validation("GitHub release asset upload URL is invalid",
         reason: :invalid_upload_url,
         subject: :upload_url
       )}
    end
  end

  def release_asset_upload_params(attrs) do
    [
      name: Map.fetch!(attrs, :name),
      label: Map.get(attrs, :label)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def decode_release_asset_content(attrs) do
    attrs
    |> Map.fetch!(:content_base64)
    |> Base.decode64(ignore: :whitespace)
    |> case do
      {:ok, content} ->
        {:ok, content}

      :error ->
        {:error,
         Error.validation("GitHub release asset content must be valid base64",
           reason: :invalid_content,
           subject: :content_base64
         )}
    end
  end

  def workflow_run_job_list_params(params) do
    [
      filter: Map.get(params, :filter, "latest"),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def issue_comment_list_params(params) do
    [
      since: Map.get(params, :since),
      per_page: Map.get(params, :per_page, 30),
      page: Map.get(params, :page, 1)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def repository_list_request(%{auth_profile: :installation}),
    do: {"/installation/repositories", &Response.handle_repository_list_response/1}

  def repository_list_request(_params),
    do: {"/user/repos", &Response.handle_user_repository_list_response/1}

  def workflow_run_list_request(repo, %{workflow: workflow} = params) when is_binary(workflow),
    do: {"/repos/#{repo}/actions/workflows/#{workflow}/runs", workflow_run_list_params(params)}

  def workflow_run_list_request(repo, params),
    do: {"/repos/#{repo}/actions/runs", workflow_run_list_params(params)}

  def workflow_run_rerun_url(repo, run_id, %{failed_only: true}) do
    "/repos/#{repo}/actions/runs/#{run_id}/rerun-failed-jobs"
  end

  def workflow_run_rerun_url(repo, run_id, _opts) do
    "/repos/#{repo}/actions/runs/#{run_id}/rerun"
  end
end
