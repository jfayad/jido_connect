defmodule Jido.Connect.Slack.Handlers.Actions.ListChannels do
  @moduledoc false

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_channels(
             input,
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channels: Enum.map(result.channels, &normalize_channel/1),
         next_cursor: result.next_cursor
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:error, :slack_client_required}

  defp normalize_channel(channel) do
    %{
      id: Map.fetch!(channel, :id),
      name: Map.get(channel, :name),
      is_archived: Map.get(channel, :is_archived),
      is_private: Map.get(channel, :is_private),
      is_member: Map.get(channel, :is_member)
    }
  end
end
