defmodule Jido.Connect.GitHub.Handlers.Actions.ListCommits do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, commits} <-
           client.list_commits(
             commit_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{commits: Enum.map(commits, &normalize_commit/1)}}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp commit_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      ref: Map.get(input, :ref),
      path: Map.get(input, :path),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp normalize_commit(commit) do
    %{
      sha: Map.fetch!(commit, :sha),
      url: Map.get(commit, :url),
      message: Map.get(commit, :message),
      author: Map.get(commit, :author),
      committer: Map.get(commit, :committer),
      authored_at: Map.get(commit, :authored_at),
      committed_at: Map.get(commit, :committed_at),
      parents: Map.get(commit, :parents, [])
    }
    |> Data.compact()
  end
end
