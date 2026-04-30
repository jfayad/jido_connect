defmodule Jido.Connect.Slack.Handlers.Actions.PostEphemeral do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @channel_pattern ~r/^[CGD][A-Z0-9]+$/
  @user_pattern ~r/^[UW][A-Z0-9]+$/

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, message} <-
           client.post_ephemeral(
             Map.take(input, [:channel, :user, :text, :thread_ts, :blocks]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Data.get(message, :channel, Data.get(input, :channel)),
         user: Data.get(message, :user, Data.get(input, :user)),
         message_ts: Data.get(message, :message_ts)
       }}
    end
  end

  defp validate_input(%{channel: channel, user: user}) do
    with :ok <- validate_channel(channel),
         :ok <- validate_user(user) do
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

  defp validate_user(user) when is_binary(user) do
    if Regex.match?(@user_pattern, user) do
      :ok
    else
      validation_error("Slack user must be a user id", :user, user)
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
