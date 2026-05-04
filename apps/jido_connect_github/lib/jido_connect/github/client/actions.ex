defmodule Jido.Connect.GitHub.Client.Actions do
  @moduledoc "GitHub Actions workflow API boundary."

  alias Jido.Connect.GitHub.Client.{Params, Response, Transport}

  def list_workflow_runs(%{repo: repo} = params, access_token)
      when is_binary(repo) and is_binary(access_token) do
    {url, request_params} = Params.workflow_run_list_request(repo, params)

    access_token
    |> Transport.request()
    |> Req.get(url: url, params: request_params)
    |> Response.handle_workflow_run_list_response()
  end

  def list_workflow_run_jobs(%{repo: repo, run_id: run_id} = params, access_token)
      when is_binary(repo) and is_integer(run_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/actions/runs/#{run_id}/jobs",
      params: Params.workflow_run_job_list_params(params)
    )
    |> Response.handle_workflow_run_job_list_response()
  end

  def rerun_workflow_run(repo, run_id, opts, access_token)
      when is_binary(repo) and is_integer(run_id) and is_map(opts) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: Params.workflow_run_rerun_url(repo, run_id, opts))
    |> Response.handle_workflow_run_rerun_response()
  end

  def cancel_workflow_run(repo, run_id, access_token)
      when is_binary(repo) and is_integer(run_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/repos/#{repo}/actions/runs/#{run_id}/cancel")
    |> Response.handle_workflow_run_cancel_response()
  end

  def dispatch_workflow(repo, workflow, attrs, access_token)
      when is_binary(repo) and is_binary(workflow) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/repos/#{repo}/actions/workflows/#{workflow}/dispatches", json: attrs)
    |> Response.handle_workflow_dispatch_response()
  end
end
