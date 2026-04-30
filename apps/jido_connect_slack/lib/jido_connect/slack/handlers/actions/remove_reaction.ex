defmodule Jido.Connect.Slack.Handlers.Actions.RemoveReaction do
  @moduledoc false

  alias Jido.Connect.Error

  @channel_pattern ~r/^[CGD][A-Z0-9]+$/
  @timestamp_pattern ~r/^\d+\.\d{6}$/
  @reaction_name_pattern ~r/^[a-z0-9_+-]+$/

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, reaction} <-
           client.remove_reaction(
             Map.take(input, [:channel, :timestamp, :name]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Map.fetch!(reaction, :channel),
         timestamp: Map.fetch!(reaction, :timestamp),
         name: Map.fetch!(reaction, :name)
       }}
    end
  end

  defp validate_input(%{channel: channel, timestamp: timestamp, name: name}) do
    with :ok <- validate_channel(channel),
         :ok <- validate_timestamp(timestamp),
         :ok <- validate_reaction_name(name) do
      :ok
    end
  end

  defp validate_channel(channel) when is_binary(channel) do
    if Regex.match?(@channel_pattern, channel) do
      :ok
    else
      validation_error("Slack channel must be a conversation id", :channel, channel)
    end
  end

  defp validate_timestamp(timestamp) when is_binary(timestamp) do
    if Regex.match?(@timestamp_pattern, timestamp) do
      :ok
    else
      validation_error("Slack timestamp must use Slack ts format", :timestamp, timestamp)
    end
  end

  defp validate_reaction_name(name) when is_binary(name) do
    if Regex.match?(@reaction_name_pattern, name) do
      :ok
    else
      validation_error("Slack reaction name must be an emoji name without colons", :name, name)
    end
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
