defmodule Jido.Connect.GitHub.Handlers.Actions.ListInstallationRepositories do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials} = runtime) do
    with :ok <- require_installation_profile(runtime),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_repositories(
             %{
               auth_profile: :installation,
               page: Map.get(input, :page, 1),
               per_page: Map.get(input, :per_page, 30)
             },
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         repositories: Enum.map(result.repositories, &normalize_repository/1),
         total_count: result.total_count,
         permissions: installation_permissions(runtime)
       }}
    end
  end

  defp require_installation_profile(%{context: %{connection: %{profile: :installation}}}), do: :ok
  defp require_installation_profile(%{credential_lease: %{profile: :installation}}), do: :ok

  defp require_installation_profile(_runtime) do
    {:error,
     Error.validation(
       "GitHub installation repository listing requires an installation connection",
       field: :connection
     )}
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp installation_permissions(%{credential_lease: %{metadata: %{permissions: permissions}}})
       when is_map(permissions),
       do: permissions

  defp installation_permissions(_runtime), do: %{}

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
