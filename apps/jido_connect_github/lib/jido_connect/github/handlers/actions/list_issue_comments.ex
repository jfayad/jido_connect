defmodule Jido.Connect.GitHub.Handlers.Actions.ListIssueComments do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, comments} <-
           client.list_issue_comments(
             comment_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{comments: Enum.map(comments, &normalize_comment/1)}}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp comment_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      issue_number: Map.fetch!(input, :issue_number),
      since: Map.get(input, :since),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp normalize_comment(comment) do
    %{
      id: Map.fetch!(comment, :id),
      url: Map.fetch!(comment, :url),
      body: Map.fetch!(comment, :body),
      user: Map.get(comment, :user),
      author_association: Map.get(comment, :author_association),
      created_at: Map.get(comment, :created_at),
      updated_at: Map.get(comment, :updated_at)
    }
    |> Data.compact()
  end
end
