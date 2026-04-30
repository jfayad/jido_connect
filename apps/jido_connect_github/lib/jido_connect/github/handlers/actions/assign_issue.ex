defmodule Jido.Connect.GitHub.Handlers.Actions.AssignIssue do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, assignees} <- validate_assignees(Map.fetch!(input, :assignees)),
         {:ok, client} <- fetch_client(credentials),
         {:ok, issue} <-
           client.assign_issue(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :issue_number),
             assignees,
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         number: Map.fetch!(issue, :number),
         url: Map.fetch!(issue, :url),
         title: Map.fetch!(issue, :title),
         state: Map.fetch!(issue, :state),
         assignees: Map.get(issue, :assignees, [])
       }}
    end
  end

  defp validate_assignees(assignees) when is_list(assignees) and assignees != [] do
    if Enum.all?(assignees, &(is_binary(&1) and String.trim(&1) != "")) do
      {:ok, assignees}
    else
      {:error,
       Error.validation("GitHub issue assignees must be non-empty logins",
         reason: :invalid_assignees,
         subject: :assignees
       )}
    end
  end

  defp validate_assignees(_assignees) do
    {:error,
     Error.validation("At least one GitHub issue assignee is required",
       reason: :empty_assignees,
       subject: :assignees
     )}
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
