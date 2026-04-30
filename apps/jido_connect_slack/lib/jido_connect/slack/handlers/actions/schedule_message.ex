defmodule Jido.Connect.Slack.Handlers.Actions.ScheduleMessage do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @max_schedule_seconds 120 * 24 * 60 * 60

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_post_at(Data.get(input, :post_at)),
         {:ok, client} <- fetch_client(credentials),
         {:ok, message} <-
           client.schedule_message(
             input
             |> Map.take([:channel, :text, :post_at, :thread_ts, :reply_broadcast, :blocks])
             |> Map.put_new(:reply_broadcast, false),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Data.fetch!(message, :channel),
         scheduled_message_id: Data.fetch!(message, :scheduled_message_id),
         post_at: Data.fetch!(message, :post_at),
         message: Data.get(message, :message, %{})
       }}
    end
  end

  defp validate_post_at(post_at) when is_integer(post_at) do
    now = System.system_time(:second)

    cond do
      post_at <= now ->
        post_at_error("Slack scheduled message post_at must be in the future", post_at)

      post_at > now + @max_schedule_seconds ->
        post_at_error("Slack scheduled message post_at must be within 120 days", post_at)

      true ->
        :ok
    end
  end

  defp validate_post_at(post_at) do
    post_at_error("Slack scheduled message post_at must be a Unix timestamp in seconds", post_at)
  end

  defp post_at_error(message, value) do
    {:error,
     Error.validation(message,
       reason: :invalid_input,
       subject: value,
       details: %{field: :post_at}
     )}
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
