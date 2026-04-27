defmodule Jido.Connect.GitHub.Handlers.Triggers.NewIssuesPoller do
  @moduledoc false

  alias Jido.Connect.{Error, Polling}

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, issues} <-
           client.list_new_issues(
             Map.fetch!(config, :repo),
             checkpoint,
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         signals: Enum.map(issues, &normalize_signal(config.repo, &1)),
         checkpoint: Polling.latest_checkpoint(issues, :updated_at, checkpoint)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp normalize_signal(repo, issue) do
    %{
      repo: repo,
      issue_number: Map.fetch!(issue, :number),
      title: Map.fetch!(issue, :title),
      url: Map.fetch!(issue, :url)
    }
  end
end
