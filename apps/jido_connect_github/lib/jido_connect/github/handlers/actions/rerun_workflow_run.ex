defmodule Jido.Connect.GitHub.Handlers.Actions.RerunWorkflowRun do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.rerun_workflow_run(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :run_id),
             rerun_opts(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         rerun_requested: Map.get(result, :rerun_requested, true),
         repo: Map.fetch!(input, :repo),
         run_id: Map.fetch!(input, :run_id),
         failed_only: Map.get(input, :failed_only, false)
       }}
    end
  end

  defp rerun_opts(input) do
    %{failed_only: Map.get(input, :failed_only, false)}
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
