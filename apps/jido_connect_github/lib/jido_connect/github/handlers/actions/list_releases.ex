defmodule Jido.Connect.GitHub.Handlers.Actions.ListReleases do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, %{releases: releases, tags: tags}} <-
           client.list_releases(
             release_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         releases: Enum.map(releases, &normalize_release/1),
         tags: Enum.map(tags, &normalize_tag/1)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp release_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp normalize_release(release) do
    %{
      id: Map.fetch!(release, :id),
      tag_name: Map.fetch!(release, :tag_name),
      name: Map.get(release, :name),
      draft: Map.get(release, :draft),
      prerelease: Map.get(release, :prerelease),
      target_commitish: Map.get(release, :target_commitish),
      author: Map.get(release, :author),
      url: Map.get(release, :url),
      upload_url: Map.get(release, :upload_url),
      tarball_url: Map.get(release, :tarball_url),
      zipball_url: Map.get(release, :zipball_url),
      created_at: Map.get(release, :created_at),
      published_at: Map.get(release, :published_at),
      body: Map.get(release, :body)
    }
    |> Data.compact()
  end

  defp normalize_tag(tag) do
    %{
      name: Map.fetch!(tag, :name),
      sha: Map.get(tag, :sha),
      url: Map.get(tag, :url)
    }
    |> Data.compact()
  end
end
