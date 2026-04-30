defmodule Jido.Connect.Slack.Handlers.Actions.RemovePin do
  @moduledoc false

  alias Jido.Connect.Error

  @channel_pattern ~r/^[CGD][A-Z0-9]+$/
  @timestamp_pattern ~r/^\d+\.\d{6}$/

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, pin} <-
           client.remove_pin(
             Map.take(input, [:channel, :timestamp]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         type: Map.fetch!(pin, :type),
         channel: Map.fetch!(pin, :channel),
         timestamp: Map.fetch!(pin, :timestamp)
       }}
    end
  end

  defp validate_input(%{channel: channel, timestamp: timestamp}) do
    with :ok <- validate_channel(channel),
         :ok <- validate_timestamp(timestamp) do
      :ok
    end
  end

  defp validate_channel(channel) when is_binary(channel) do
    if Regex.match?(@channel_pattern, channel) do
      :ok
    else
      validation_error("Slack pin item channel must be a conversation id", :channel, channel)
    end
  end

  defp validate_channel(channel) do
    validation_error("Slack pin item channel must be a conversation id", :channel, channel)
  end

  defp validate_timestamp(timestamp) when is_binary(timestamp) do
    if Regex.match?(@timestamp_pattern, timestamp) do
      :ok
    else
      validation_error("Slack pin item timestamp must use Slack ts format", :timestamp, timestamp)
    end
  end

  defp validate_timestamp(timestamp) do
    validation_error("Slack pin item timestamp must use Slack ts format", :timestamp, timestamp)
  end

  defp validation_error(message, field, value) do
    {:error,
     Error.validation(message,
       reason: :invalid_input,
       subject: value,
       details: %{field: field}
     )}
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
