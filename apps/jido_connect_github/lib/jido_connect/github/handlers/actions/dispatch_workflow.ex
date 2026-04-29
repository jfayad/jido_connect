defmodule Jido.Connect.GitHub.Handlers.Actions.DispatchWorkflow do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.dispatch_workflow(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :workflow),
             dispatch_attrs(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         dispatched: Map.get(result, :dispatched, true),
         repo: Map.fetch!(input, :repo),
         workflow: Map.fetch!(input, :workflow),
         ref: Map.fetch!(input, :ref)
       }}
    end
  end

  defp dispatch_attrs(input) do
    %{
      ref: Map.fetch!(input, :ref),
      inputs: Map.get(input, :inputs, %{})
    }
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
