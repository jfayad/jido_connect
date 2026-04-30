defmodule Jido.Connect.GitHub.Handlers.Actions.ListPullRequestFiles do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, files} <-
           client.list_pull_request_files(
             file_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{files: Enum.map(files, &normalize_file/1)}}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp file_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      pull_number: Map.fetch!(input, :pull_number),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
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
  end
end
