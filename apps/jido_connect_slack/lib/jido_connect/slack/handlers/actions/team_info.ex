defmodule Jido.Connect.Slack.Handlers.Actions.TeamInfo do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <- client.team_info(input, Map.get(credentials, :access_token)) do
      team = Data.get(result, :team, %{})

      {:ok, normalize_team(team)}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end

  defp normalize_team(team) do
    %{
      team_id: Data.get(team, "id"),
      name: Data.get(team, "name"),
      domain: Data.get(team, "domain"),
      email_domain: Data.get(team, "email_domain"),
      enterprise_id: Data.get(team, "enterprise_id"),
      enterprise_name: Data.get(team, "enterprise_name"),
      team: team
    }
    |> Data.compact()
  end
end
