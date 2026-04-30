defmodule Jido.Connect.Slack.Handlers.Actions.OpenConversation do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.open_conversation(
             Map.take(input, [:users, :channel, :return_im, :prevent_creation]),
             Map.get(credentials, :access_token)
           ) do
      conversation = Data.get(result, :conversation, %{})

      {:ok,
       %{
         channel: Data.get(result, :channel, Data.get(conversation, :id)),
         conversation: conversation
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
