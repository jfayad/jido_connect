defmodule Jido.Connect.GitHub.Handlers.Actions.UpdatePullRequest do
  @moduledoc false

  alias Jido.Connect.Error

  @updatable_fields [:title, :body, :base, :state, :maintainer_can_modify, :draft]

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, pull_request} <-
           client.update_pull_request(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :pull_number),
             update_attrs(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         number: Map.fetch!(pull_request, :number),
         url: Map.fetch!(pull_request, :url),
         title: Map.fetch!(pull_request, :title),
         state: Map.fetch!(pull_request, :state)
       }}
    end
  end

  defp update_attrs(input) do
    Enum.reduce(@updatable_fields, %{}, fn field, attrs ->
      if Map.has_key?(input, field) do
        Map.put(attrs, field, Map.fetch!(input, field))
      else
        attrs
      end
    end)
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
