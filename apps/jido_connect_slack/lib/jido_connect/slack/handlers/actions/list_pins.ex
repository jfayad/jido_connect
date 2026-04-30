defmodule Jido.Connect.Slack.Handlers.Actions.ListPins do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @channel_pattern ~r/^[CGD][A-Z0-9]+$/

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_channel(Data.get(input, :channel)),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_pins(
             Map.take(input, [:channel]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Data.get(result, :channel, Data.get(input, :channel)),
         items: Enum.map(Data.get(result, :items, []), &normalize_item/1)
       }}
    end
  end

  defp validate_channel(channel) when is_binary(channel) do
    if Regex.match?(@channel_pattern, channel) do
      :ok
    else
      validation_error("Slack channel must be a conversation id", :channel, channel)
    end
  end

  defp validate_channel(channel),
    do: validation_error("Slack channel must be a conversation id", :channel, channel)

  defp normalize_item(item) do
    message = Data.get(item, :message)
    file = Data.get(item, :file)
    file_comment = Data.get(item, :file_comment, Data.get(item, :comment))

    %{
      type: Data.get(item, :type),
      channel: Data.get(item, :channel, Data.get(message, :channel)),
      timestamp: Data.get(item, :timestamp, Data.get(message, :ts)),
      created: Data.get(item, :created),
      created_by: Data.get(item, :created_by),
      message: message,
      file: file,
      file_comment: file_comment
    }
    |> Data.compact()
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end

  defp validation_error(message, field, value) do
    {:error,
     Error.validation(message,
       subject: value,
       details: %{field: field},
       reason: :invalid_input
     )}
  end
end
