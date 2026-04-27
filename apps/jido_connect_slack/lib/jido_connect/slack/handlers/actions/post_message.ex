defmodule Jido.Connect.Slack.Handlers.Actions.PostMessage do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, message} <-
           client.post_message(
             input
             |> Map.take([:channel, :text, :thread_ts, :reply_broadcast])
             |> Map.put_new(:reply_broadcast, false),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Map.fetch!(message, :channel),
         ts: Map.fetch!(message, :ts),
         message: Map.get(message, :message, %{})
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
