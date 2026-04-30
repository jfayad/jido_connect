defmodule Jido.Connect.Slack.Handlers.Actions.ListReactions do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @channel_pattern ~r/^[CGD][A-Z0-9]+$/
  @timestamp_pattern ~r/^\d+\.\d{6}$/
  @file_pattern ~r/^F[A-Z0-9]+$/

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.get_reactions(
             Map.take(input, [:channel, :timestamp, :file, :file_comment, :full]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         type: Data.get(result, :type),
         channel: Data.get(result, :channel, Data.get(input, :channel)),
         timestamp: Data.get(result, :timestamp, Data.get(input, :timestamp)),
         file_id: Data.get(result, :file_id, Data.get(input, :file)),
         file_comment_id: Data.get(result, :file_comment_id, Data.get(input, :file_comment)),
         message: Data.get(result, :message),
         file: Data.get(result, :file),
         file_comment: Data.get(result, :file_comment),
         reactions: Data.get(result, :reactions, [])
       }
       |> Data.compact()}
    end
  end

  defp validate_input(input) do
    with :ok <- validate_target(input),
         :ok <- validate_channel(Data.get(input, :channel)),
         :ok <- validate_timestamp(Data.get(input, :timestamp)),
         :ok <- validate_file(Data.get(input, :file)),
         :ok <- validate_file_comment(Data.get(input, :file_comment)) do
      :ok
    end
  end

  defp validate_target(input) do
    message? = present?(Data.get(input, :channel)) or present?(Data.get(input, :timestamp))
    file? = present?(Data.get(input, :file)) or present?(Data.get(input, :file_comment))

    cond do
      message? and file? ->
        validation_error(
          "Slack reactions target must be either a message or a file",
          :target,
          input
        )

      message? ->
        validate_message_target(input)

      file? ->
        validate_file_target(input)

      true ->
        validation_error("Slack reactions target is required", :target, input)
    end
  end

  defp validate_message_target(input) do
    if present?(Data.get(input, :channel)) and present?(Data.get(input, :timestamp)) do
      :ok
    else
      validation_error(
        "Slack message reactions target requires channel and timestamp",
        :target,
        input
      )
    end
  end

  defp validate_file_target(input) do
    if present?(Data.get(input, :file)) do
      :ok
    else
      validation_error("Slack file comment reactions target requires file", :file, input)
    end
  end

  defp validate_channel(nil), do: :ok

  defp validate_channel(channel) when is_binary(channel) do
    if Regex.match?(@channel_pattern, channel) do
      :ok
    else
      validation_error("Slack channel must be a conversation id", :channel, channel)
    end
  end

  defp validate_channel(channel),
    do: validation_error("Slack channel must be a conversation id", :channel, channel)

  defp validate_timestamp(nil), do: :ok

  defp validate_timestamp(timestamp) when is_binary(timestamp) do
    if Regex.match?(@timestamp_pattern, timestamp) do
      :ok
    else
      validation_error("Slack timestamp must use Slack ts format", :timestamp, timestamp)
    end
  end

  defp validate_timestamp(timestamp),
    do: validation_error("Slack timestamp must use Slack ts format", :timestamp, timestamp)

  defp validate_file(nil), do: :ok

  defp validate_file(file) when is_binary(file) do
    if Regex.match?(@file_pattern, file) do
      :ok
    else
      validation_error("Slack file must be a file id", :file, file)
    end
  end

  defp validate_file(file), do: validation_error("Slack file must be a file id", :file, file)

  defp validate_file_comment(nil), do: :ok

  defp validate_file_comment(file_comment) when is_binary(file_comment) do
    if present?(file_comment) do
      :ok
    else
      validation_error(
        "Slack file comment must be a file comment id",
        :file_comment,
        file_comment
      )
    end
  end

  defp validate_file_comment(file_comment) do
    validation_error("Slack file comment must be a file comment id", :file_comment, file_comment)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)

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
