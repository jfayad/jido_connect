defmodule Jido.Connect.Slack.Handlers.Actions.AuthTest do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(_input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, auth} <- client.auth_test(Map.get(credentials, :access_token)) do
      {:ok, normalize_auth(auth)}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end

  defp normalize_auth(auth) do
    %{
      team_id: Data.get(auth, "team_id"),
      team: Data.get(auth, "team"),
      url: Data.get(auth, "url"),
      user_id: Data.get(auth, "user_id"),
      user: Data.get(auth, "user"),
      bot_id: Data.get(auth, "bot_id"),
      enterprise_id: Data.get(auth, "enterprise_id"),
      is_enterprise_install: Data.get(auth, "is_enterprise_install")
    }
    |> Data.compact()
  end
end
