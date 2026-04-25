defmodule Jido.Connect.GitHub.Handlers.Triggers.NewIssuesPoller do
  @moduledoc false

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
         checkpoint: latest_checkpoint(issues, checkpoint)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:error, :github_client_required}

  defp normalize_signal(repo, issue) do
    %{
      repo: repo,
      issue_number: Map.fetch!(issue, :number),
      title: Map.fetch!(issue, :title),
      url: Map.fetch!(issue, :url)
    }
  end

  defp latest_checkpoint([], checkpoint), do: checkpoint

  defp latest_checkpoint(issues, _checkpoint) do
    issues
    |> Enum.map(&Map.get(&1, :updated_at))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort(:desc)
    |> List.first()
  end
end
