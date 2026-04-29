defmodule Jido.Connect.GitHub.Handlers.Actions.MergePullRequest do
  @moduledoc false

  alias Jido.Connect.Error

  @merge_fields [:merge_method, :commit_title, :commit_message, :sha]

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.merge_pull_request(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :pull_number),
             merge_attrs(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         sha: Map.get(result, :sha),
         merged: Map.fetch!(result, :merged),
         message: Map.fetch!(result, :message)
       }}
    end
  end

  defp merge_attrs(input) do
    Enum.reduce(@merge_fields, %{}, fn field, attrs ->
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
