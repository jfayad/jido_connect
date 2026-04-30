defmodule Jido.Connect.GitHub.Handlers.Actions.ListWorkflowRunJobs do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, %{jobs: jobs, total_count: total_count, ci_status: ci_status}} <-
           client.list_workflow_run_jobs(
             workflow_run_job_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         jobs: Enum.map(jobs, &normalize_job/1),
         total_count: total_count,
         ci_status: ci_status
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp workflow_run_job_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      run_id: Map.fetch!(input, :run_id),
      filter: Map.get(input, :filter, "latest"),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp normalize_job(job) do
    %{
      id: Map.fetch!(job, :id),
      run_id: Map.get(job, :run_id),
      run_attempt: Map.get(job, :run_attempt),
      name: Map.get(job, :name),
      status: Map.get(job, :status),
      conclusion: Map.get(job, :conclusion),
      ci_status: Map.get(job, :ci_status),
      steps: Enum.map(Map.get(job, :steps, []), &normalize_step/1),
      url: Map.get(job, :url),
      started_at: Map.get(job, :started_at),
      completed_at: Map.get(job, :completed_at)
    }
  end

  defp normalize_step(step) do
    %{
      number: Map.get(step, :number),
      name: Map.get(step, :name),
      status: Map.get(step, :status),
      conclusion: Map.get(step, :conclusion),
      ci_status: Map.get(step, :ci_status),
      started_at: Map.get(step, :started_at),
      completed_at: Map.get(step, :completed_at)
    }
  end
end
