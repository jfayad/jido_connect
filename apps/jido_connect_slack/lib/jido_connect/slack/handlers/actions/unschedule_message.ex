defmodule Jido.Connect.Slack.Handlers.Actions.UnscheduleMessage do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, message} <-
           client.delete_scheduled_message(
             Map.take(input, [:channel, :scheduled_message_id]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Map.fetch!(message, :channel),
         scheduled_message_id: Map.fetch!(message, :scheduled_message_id)
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
