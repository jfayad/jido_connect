defmodule Jido.Connect.Google.Calendar.Handlers.Actions.UpdateEvent do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Client
  alias Jido.Connect.Google.Calendar.Handlers.Actions.EventMutation

  def run(input, %{credentials: credentials}) do
    with :ok <- EventMutation.validate_update(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, event} <-
           client.update_event(
             EventMutation.normalize_update(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{event: public_map(event)}}
    end
  end

  defp fetch_client(%{google_calendar_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
