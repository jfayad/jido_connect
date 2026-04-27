defmodule Jido.Connect.GitHub.Handlers.Actions.ListIssues do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, issues} <-
           client.list_issues(
             Map.fetch!(input, :repo),
             Map.get(input, :state, "open"),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{issues: Enum.map(issues, &normalize_issue/1)}}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp normalize_issue(issue) do
    %{
      number: Map.fetch!(issue, :number),
      url: Map.fetch!(issue, :url),
      title: Map.fetch!(issue, :title),
      state: Map.fetch!(issue, :state)
    }
  end
end
