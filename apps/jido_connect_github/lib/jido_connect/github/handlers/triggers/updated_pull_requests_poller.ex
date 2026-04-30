defmodule Jido.Connect.GitHub.Handlers.Triggers.UpdatedPullRequestsPoller do
  @moduledoc false

  alias Jido.Connect.{Error, Polling}

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, pull_requests} <-
           client.list_updated_pull_requests(
             Map.fetch!(config, :repo),
             checkpoint,
             Map.get(credentials, :access_token)
           ) do
      pull_requests = Enum.reject(pull_requests, &duplicate_checkpoint?(&1, checkpoint))

      {:ok,
       %{
         signals: Enum.map(pull_requests, &normalize_signal(config.repo, &1)),
         checkpoint: Polling.latest_checkpoint(pull_requests, :updated_at, checkpoint)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp duplicate_checkpoint?(_pull_request, checkpoint) when checkpoint in [nil, ""], do: false

  defp duplicate_checkpoint?(pull_request, checkpoint) do
    Map.get(pull_request, :updated_at) == checkpoint
  end

  defp normalize_signal(repo, pull_request) do
    %{
      repo: repo,
      pull_number: Map.fetch!(pull_request, :number),
      title: Map.fetch!(pull_request, :title),
      state: Map.fetch!(pull_request, :state),
      url: Map.fetch!(pull_request, :url),
      updated_at: Map.fetch!(pull_request, :updated_at)
    }
  end
end
