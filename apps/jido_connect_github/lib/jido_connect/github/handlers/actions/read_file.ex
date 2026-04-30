defmodule Jido.Connect.GitHub.Handlers.Actions.ReadFile do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, file} <-
           client.read_file(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :path),
             Map.get(input, :ref),
             Map.get(credentials, :access_token)
           ) do
      {:ok, Map.put(file, :repo, Map.fetch!(input, :repo))}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
