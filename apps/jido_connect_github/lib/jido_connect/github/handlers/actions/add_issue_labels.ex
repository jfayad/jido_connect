defmodule Jido.Connect.GitHub.Handlers.Actions.AddIssueLabels do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, labels} <- validate_labels(Map.fetch!(input, :labels)),
         {:ok, client} <- fetch_client(credentials),
         {:ok, labels} <-
           client.add_issue_labels(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :issue_number),
             labels,
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{labels: labels}}
    end
  end

  defp validate_labels(labels) when is_list(labels) and labels != [], do: {:ok, labels}

  defp validate_labels(_labels) do
    {:error,
     Error.validation("At least one GitHub issue label is required",
       reason: :empty_labels,
       subject: :labels
     )}
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
