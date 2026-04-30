defmodule Jido.Connect.GitHub.Handlers.Actions.CreateBranch do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, attrs} <- branch_attrs(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, branch} <-
           client.create_branch(
             Map.fetch!(input, :repo),
             attrs,
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       branch
       |> Map.put(:repo, Map.fetch!(input, :repo))
       |> Map.put(:branch, Map.fetch!(input, :branch))}
    end
  end

  defp branch_attrs(input) do
    source_ref = blank_to_nil(Map.get(input, :source_ref))
    source_sha = blank_to_nil(Map.get(input, :source_sha))

    case {source_ref, source_sha} do
      {nil, nil} ->
        source_required()

      {source_ref, nil} ->
        {:ok, %{branch: Map.fetch!(input, :branch), source_ref: source_ref}}

      {nil, source_sha} ->
        {:ok, %{branch: Map.fetch!(input, :branch), source_sha: source_sha}}

      {_source_ref, _source_sha} ->
        {:error,
         Error.validation("GitHub branch creation accepts source_ref or source_sha, not both",
           reason: :ambiguous_source,
           subject: :source
         )}
    end
  end

  defp source_required do
    {:error,
     Error.validation("GitHub branch creation requires source_ref or source_sha",
       reason: :missing_source,
       subject: :source
     )}
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value) when is_binary(value), do: value

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
