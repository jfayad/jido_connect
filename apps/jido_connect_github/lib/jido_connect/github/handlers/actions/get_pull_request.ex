defmodule Jido.Connect.GitHub.Handlers.Actions.GetPullRequest do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, pull_request} <-
           client.get_pull_request(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :pull_number),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{pull_request: pull_request}}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
