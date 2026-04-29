defmodule Jido.Connect.GitHub.Handlers.Actions.CreatePullRequest do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         attrs = %{
           title: Map.fetch!(input, :title),
           body: Map.get(input, :body),
           head: Map.fetch!(input, :head),
           base: Map.fetch!(input, :base),
           draft: Map.get(input, :draft, false),
           maintainer_can_modify: Map.get(input, :maintainer_can_modify, true)
         },
         {:ok, pull_request} <-
           client.create_pull_request(
             Map.fetch!(input, :repo),
             attrs,
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

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
