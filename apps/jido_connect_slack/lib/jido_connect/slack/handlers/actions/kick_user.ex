defmodule Jido.Connect.Slack.Handlers.Actions.KickUser do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @channel_pattern ~r/^[CG][A-Z0-9]+$/
  @user_pattern ~r/^[UW][A-Z0-9]+$/

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.kick_conversation(
             Map.take(input, [:channel, :user]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Data.get(result, :channel, Data.get(input, :channel)),
         user: Data.get(result, :user, Data.get(input, :user))
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
      validation_error("Slack channel must be a public or private channel id", :channel, channel)
    end
  end

  defp validate_channel(channel) do
    validation_error("Slack channel is required", :channel, channel)
  end

  defp validate_user(user) when is_binary(user) do
    if Regex.match?(@user_pattern, user) do
      :ok
    else
      validation_error("Slack user must be a user id", :user, user)
    end
  end

  defp validate_user(user) do
    validation_error("Slack user is required", :user, user)
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
