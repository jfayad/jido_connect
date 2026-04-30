defmodule Jido.Connect.GitHub.Handlers.Triggers.WorkflowRunUpdatesPoller do
  @moduledoc false

  alias Jido.Connect.{Data, Error, Polling}

  @failure_conclusions ~w(failure startup_failure timed_out action_required cancelled)

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, %{workflow_runs: workflow_runs}} <-
           client.list_workflow_runs(
             workflow_run_params(config, checkpoint),
             Map.get(credentials, :access_token)
           ) do
      workflow_runs =
        workflow_runs
        |> Enum.filter(&after_checkpoint?(&1, checkpoint))
        |> Enum.sort_by(&Map.get(&1, :updated_at, ""))

      {:ok,
       %{
         signals: Enum.map(workflow_runs, &normalize_signal(config.repo, &1)),
         checkpoint: Polling.latest_checkpoint(workflow_runs, :updated_at, checkpoint)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp workflow_run_params(config, checkpoint) do
    %{
      repo: Map.fetch!(config, :repo),
      workflow: Map.get(config, :workflow),
      branch: Map.get(config, :branch),
      status: Map.get(config, :status),
      event: Map.get(config, :event),
      page: 1,
      per_page: Map.get(config, :per_page, 30),
      checkpoint: checkpoint
    }
    |> Data.compact()
  end

  defp after_checkpoint?(_workflow_run, checkpoint) when checkpoint in [nil, ""], do: true

  defp after_checkpoint?(workflow_run, checkpoint) do
    case Map.get(workflow_run, :updated_at) do
      updated_at when is_binary(updated_at) -> updated_at > checkpoint
      _updated_at -> false
    end
  end

  defp normalize_signal(repo, workflow_run) do
    conclusion = Map.get(workflow_run, :conclusion)
    status = Map.get(workflow_run, :status)

    %{
      repo: repo,
      workflow_run_id: Map.fetch!(workflow_run, :id),
      workflow_run_number: Map.get(workflow_run, :number),
      workflow_name: Map.get(workflow_run, :name),
      action: signal_action(status),
      status: status,
      conclusion: conclusion,
      ci_status: normalize_ci_status(status, conclusion),
      failure: failure?(conclusion),
      branch: Map.get(workflow_run, :branch),
      sha: Map.get(workflow_run, :sha),
      workflow_id: Map.get(workflow_run, :workflow_id),
      url: Map.get(workflow_run, :url),
      created_at: Map.get(workflow_run, :created_at),
      updated_at: Map.get(workflow_run, :updated_at),
      workflow_run: workflow_run
    }
    |> Data.compact()
  end

  defp signal_action("completed"), do: "completed"
  defp signal_action(_status), do: "updated"

  defp normalize_ci_status(_status, conclusion)
       when conclusion in [
              "success",
              "failure",
              "cancelled",
              "skipped",
              "timed_out",
              "action_required",
              "neutral"
            ],
       do: conclusion

  defp normalize_ci_status(status, _conclusion) when status in ["queued", "waiting", "requested"],
    do: "queued"

  defp normalize_ci_status(status, _conclusion) when status in ["in_progress", "pending"],
    do: "in_progress"

  defp normalize_ci_status("completed", _conclusion), do: "unknown"
  defp normalize_ci_status(status, _conclusion) when is_binary(status), do: status
  defp normalize_ci_status(_status, _conclusion), do: "unknown"

  defp failure?(conclusion), do: conclusion in @failure_conclusions
end
