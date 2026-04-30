defmodule Jido.Connect.Slack.Handlers.Actions.InviteUsers do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @channel_pattern ~r/^[CG][A-Z0-9]+$/
  @user_pattern ~r/^[UW][A-Z0-9]+$/
  @max_users 1000

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.invite_conversation(
             Map.take(input, [:channel, :users, :force]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Data.get(result, :channel),
         invited_users: Data.get(result, :invited_users, Data.get(input, :users, [])),
         failed_users: Data.get(result, :failed_users, []),
         partial_failure: Data.get(result, :partial_failure, false)
       }}
    end
  end

  defp validate_input(%{channel: channel, users: users}) do
    with :ok <- validate_channel(channel),
         :ok <- validate_users(users) do
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

  defp validate_users(users) when is_list(users) do
    cond do
      users == [] ->
        validation_error("At least one Slack user is required", :users, users)

      length(users) > @max_users ->
        validation_error("Slack conversations.invite accepts at most 1000 users", :users, users)

      Enum.all?(users, &valid_user?/1) ->
        :ok

      true ->
        validation_error("Slack users must be user ids", :users, users)
    end
  end

  defp validate_users(users) do
    validation_error("Slack users must be a list", :users, users)
  end

  defp valid_user?(user) when is_binary(user), do: Regex.match?(@user_pattern, user)
  defp valid_user?(_user), do: false

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
