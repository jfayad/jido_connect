defmodule Jido.Connect.GitHub.Handlers.Actions.CreateRelease do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, release} <-
           client.create_release(
             Map.fetch!(input, :repo),
             release_attrs(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, normalize_release(release)}
    end
  end

  defp release_attrs(input) do
    %{
      tag_name: Map.fetch!(input, :tag_name),
      target_commitish: Map.get(input, :target_commitish),
      name: Map.get(input, :name),
      body: Map.get(input, :body),
      draft: Map.get(input, :draft, false),
      prerelease: Map.get(input, :prerelease, false),
      generate_release_notes: Map.get(input, :generate_release_notes, false),
      make_latest: Map.get(input, :make_latest, "true")
    }
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
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
      tarball_url: Map.get(release, :tarball_url),
      zipball_url: Map.get(release, :zipball_url),
      created_at: Map.get(release, :created_at),
      published_at: Map.get(release, :published_at),
      body: Map.get(release, :body)
    }
    |> Data.compact()
  end
end
