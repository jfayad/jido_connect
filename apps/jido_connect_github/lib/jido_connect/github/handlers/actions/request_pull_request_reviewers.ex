defmodule Jido.Connect.GitHub.Handlers.Actions.RequestPullRequestReviewers do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, reviewers} <- validate_logins(Map.get(input, :reviewers, []), :reviewers),
         {:ok, team_reviewers} <-
           validate_logins(Map.get(input, :team_reviewers, []), :team_reviewers),
         :ok <- validate_any_reviewers(reviewers, team_reviewers),
         {:ok, client} <- fetch_client(credentials),
         {:ok, pull_request} <-
           client.request_pull_request_reviewers(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :pull_number),
             %{reviewers: reviewers, team_reviewers: team_reviewers},
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         number: Map.fetch!(pull_request, :number),
         url: Map.fetch!(pull_request, :url),
         title: Map.fetch!(pull_request, :title),
         state: Map.fetch!(pull_request, :state),
         requested_reviewers: Map.get(pull_request, :requested_reviewers, []),
         requested_teams: Map.get(pull_request, :requested_teams, [])
       }}
    end
  end

  defp validate_logins(logins, subject) when is_list(logins) do
    if Enum.all?(logins, &(is_binary(&1) and String.trim(&1) != "")) do
      {:ok, logins}
    else
      {:error,
       Error.validation("GitHub pull request reviewers must be non-empty logins or slugs",
         reason: :invalid_reviewers,
         subject: subject
       )}
    end
  end

  defp validate_logins(_logins, subject) do
    {:error,
     Error.validation("GitHub pull request reviewers must be lists",
       reason: :invalid_reviewers,
       subject: subject
     )}
  end

  defp validate_any_reviewers([], []) do
    {:error,
     Error.validation("At least one GitHub pull request reviewer is required",
       reason: :empty_reviewers,
       subject: :reviewers
     )}
  end

  defp validate_any_reviewers(_reviewers, _team_reviewers), do: :ok

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
