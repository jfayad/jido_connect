defmodule Jido.Connect.Slack.Handlers.Actions.DeleteMessage do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, message} <-
           client.delete_message(
             Map.take(input, [:channel, :ts]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Map.fetch!(message, :channel),
         ts: Map.fetch!(message, :ts)
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
