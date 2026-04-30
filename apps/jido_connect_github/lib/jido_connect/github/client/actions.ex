defmodule Jido.Connect.GitHub.Client.Actions do
  @moduledoc "GitHub Actions workflow API boundary."

  alias Jido.Connect.GitHub.Client.Rest

  defdelegate list_workflow_runs(params, access_token), to: Rest
  defdelegate list_workflow_run_jobs(params, access_token), to: Rest
  defdelegate rerun_workflow_run(repo, run_id, opts, access_token), to: Rest
  defdelegate cancel_workflow_run(repo, run_id, access_token), to: Rest
  defdelegate dispatch_workflow(repo, workflow, attrs, access_token), to: Rest
end
