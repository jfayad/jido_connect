defmodule Jido.Connect.GitHub.Handlers.Actions.UpdateIssue do
  @moduledoc false

  alias Jido.Connect.Error

  @updatable_fields [:title, :body, :state, :labels, :milestone, :assignees, :type]

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, issue} <-
           client.update_issue(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :issue_number),
             update_attrs(input),
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
