defmodule Jido.Connect.Slack.Handlers.Actions.GetConversationInfo do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.get_conversation_info(
             Map.take(input, [:channel, :include_locale]),
             Map.get(credentials, :access_token)
           ) do
      conversation = Data.get(result, :conversation, %{})

      {:ok,
       %{
         channel: Data.get(conversation, "id", Data.get(input, :channel)),
         conversation: conversation
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
