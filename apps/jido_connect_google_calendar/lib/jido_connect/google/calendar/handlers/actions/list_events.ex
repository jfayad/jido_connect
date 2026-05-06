defmodule Jido.Connect.Google.Calendar.Handlers.Actions.ListEvents do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_events(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         events: Enum.map(Map.get(result, :events, []), &public_map/1),
         next_page_token: Map.get(result, :next_page_token),
         next_sync_token: Map.get(result, :next_sync_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:page_size, 250)
    |> Map.put_new(:single_events, true)
    |> Map.put_new(:show_deleted, false)
    |> Map.put_new(:show_hidden_invitations, false)
  end

  defp fetch_client(%{google_calendar_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
