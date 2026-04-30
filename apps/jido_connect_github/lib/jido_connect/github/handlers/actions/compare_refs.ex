defmodule Jido.Connect.GitHub.Handlers.Actions.CompareRefs do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, comparison} <-
           client.compare_refs(
             compare_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, normalize_comparison(comparison)}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp compare_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      base: Map.fetch!(input, :base),
      head: Map.fetch!(input, :head),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp normalize_comparison(comparison) do
    %{
      status: Map.fetch!(comparison, :status),
      ahead_by: Map.fetch!(comparison, :ahead_by),
      behind_by: Map.fetch!(comparison, :behind_by),
      total_commits: Map.fetch!(comparison, :total_commits),
      commits: Enum.map(Map.get(comparison, :commits, []), &normalize_commit/1),
      files: Enum.map(Map.get(comparison, :files, []), &normalize_file/1)
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

  defp normalize_file(file) do
    %{
      filename: Map.fetch!(file, :filename),
      status: Map.fetch!(file, :status),
      additions: Map.fetch!(file, :additions),
      deletions: Map.fetch!(file, :deletions),
      changes: Map.fetch!(file, :changes),
      sha: Map.get(file, :sha),
      previous_filename: Map.get(file, :previous_filename),
      blob_url: Map.get(file, :blob_url),
      raw_url: Map.get(file, :raw_url),
      contents_url: Map.get(file, :contents_url),
      patch: Map.get(file, :patch)
    }
    |> Data.compact()
  end
end
