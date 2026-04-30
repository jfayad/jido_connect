defmodule Jido.Connect.GitHub.Handlers.Actions.CancelWorkflowRun do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.cancel_workflow_run(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :run_id),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         cancel_requested: Map.get(result, :cancel_requested, true),
         repo: Map.fetch!(input, :repo),
         run_id: Map.fetch!(input, :run_id)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
