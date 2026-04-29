defmodule Jido.Connect.GitHub.Handlers.Actions.CreateIssueComment do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, comment} <-
           client.create_issue_comment(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :issue_number),
             Map.fetch!(input, :body),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         id: Map.fetch!(comment, :id),
         url: Map.fetch!(comment, :url),
         body: Map.fetch!(comment, :body)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
