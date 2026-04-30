defmodule Jido.Connect.GitHub.Handlers.Actions.ListBranches do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, branches} <-
           client.list_branches(
             branch_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{branches: Enum.map(branches, &normalize_branch/1)}}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp branch_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp normalize_branch(branch) do
    %{
      name: Map.fetch!(branch, :name),
      sha: Map.get(branch, :sha),
      commit: Map.get(branch, :commit),
      protected: Map.get(branch, :protected),
      protection_url: Map.get(branch, :protection_url)
    }
  end
end
