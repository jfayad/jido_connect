defmodule Jido.Connect.GitHub.Handlers.Actions.UpdateFile do
  @moduledoc false

  alias Jido.Connect.Error

  @attrs [:content, :message, :branch, :sha, :committer]

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.update_file(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :path),
             update_attrs(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, Map.merge(result, %{repo: Map.fetch!(input, :repo), path: Map.fetch!(input, :path)})}
    end
  end

  defp update_attrs(input) do
    Enum.reduce(@attrs, %{}, fn field, attrs ->
      if Map.has_key?(input, field) do
        Map.put(attrs, field, Map.fetch!(input, field))
      else
        attrs
      end
    end)
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
