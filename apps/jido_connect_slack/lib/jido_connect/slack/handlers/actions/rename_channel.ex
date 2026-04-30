defmodule Jido.Connect.Slack.Handlers.Actions.RenameChannel do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @channel_name_pattern ~r/^[a-z0-9_-]{1,80}$/

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_name(Data.get(input, :name)),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.rename_conversation(
             Map.take(input, [:channel, :name]),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{channel: Map.fetch!(result, :channel)}}
    end
  end

  defp validate_name(name) when is_binary(name) do
    if Regex.match?(@channel_name_pattern, name) do
      :ok
    else
      validation_error(
        "Slack channel name must be lowercase letters, numbers, dashes, or underscores"
      )
    end
  end

  defp validate_name(_name) do
    validation_error("Slack channel name is required")
  end

  defp validation_error(message) do
    {:error,
     Error.validation(message,
       reason: :invalid_input,
       details: %{field: :name}
     )}
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
