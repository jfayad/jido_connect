defmodule Jido.Connect.Slack.Handlers.Actions.ListUsers do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <- client.list_users(input, Map.get(credentials, :access_token)) do
      {:ok,
       %{
         users: Enum.map(result.users, &normalize_user/1),
         next_cursor: result.next_cursor
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end

  defp normalize_user(user) do
    %{
      id: Data.get(user, "id"),
      team_id: Data.get(user, "team_id"),
      name: Data.get(user, "name"),
      real_name: Data.get(user, "real_name"),
      tz: Data.get(user, "tz"),
      deleted: Data.get(user, "deleted"),
      is_bot: Data.get(user, "is_bot"),
      is_app_user: Data.get(user, "is_app_user"),
      updated: Data.get(user, "updated"),
      profile: Data.get(user, "profile")
    }
    |> Data.compact()
  end
end
