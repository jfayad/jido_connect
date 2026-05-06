defmodule Jido.Connect.Google.Calendar.Handlers.Actions.GetEvent do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, event} <- client.get_event(input, Map.get(credentials, :access_token)) do
      {:ok, %{event: public_map(event)}}
    end
  end

  defp fetch_client(%{google_calendar_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
