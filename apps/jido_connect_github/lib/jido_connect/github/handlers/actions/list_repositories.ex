defmodule Jido.Connect.GitHub.Handlers.Actions.ListRepositories do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials} = runtime) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_repositories(
             %{
               auth_profile: auth_profile(runtime),
               page: Map.get(input, :page, 1),
               per_page: Map.get(input, :per_page, 30)
             },
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         repositories: Enum.map(result.repositories, &normalize_repository/1),
         total_count: result.total_count
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp auth_profile(%{context: %{connection: %{profile: profile}}}) when is_atom(profile),
    do: profile

  defp auth_profile(%{credential_lease: %{profile: profile}}) when is_atom(profile), do: profile
  defp auth_profile(_runtime), do: :user

  defp normalize_repository(repository) do
    %{
      id: Map.fetch!(repository, :id),
      name: Map.fetch!(repository, :name),
      full_name: Map.fetch!(repository, :full_name),
      owner: Map.get(repository, :owner),
      private: Map.get(repository, :private),
      default_branch: Map.get(repository, :default_branch),
      url: Map.fetch!(repository, :url)
    }
  end
end
