defmodule Jido.Connect.GitHub.Handlers.Actions.CreateIssue do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         attrs = %{
           title: Map.fetch!(input, :title),
           body: Map.get(input, :body),
           labels: Map.get(input, :labels, [])
         },
         {:ok, issue} <-
           client.create_issue(
             Map.fetch!(input, :repo),
             attrs,
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         number: Map.fetch!(issue, :number),
         url: Map.fetch!(issue, :url),
         title: Map.fetch!(issue, :title),
         state: Map.fetch!(issue, :state)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
