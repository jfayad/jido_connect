defmodule Jido.Connect.Calcom.Handlers.Actions.ListBookings do
  @moduledoc false

  alias Jido.Connect.Calcom.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, params} <- list_input(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_bookings(params, ResourceHelpers.credential_token(credentials)) do
      {:ok,
       %{
         bookings:
           result
           |> Map.get(:bookings, [])
           |> Enum.map(&ResourceHelpers.public_map/1),
         next_cursor: Map.get(result, :next_cursor),
         has_more: Map.get(result, :has_more)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp list_input(input) do
    params =
      input
      |> Map.take([
        :status,
        :attendee_email,
        :event_type_id,
        :after_start,
        :before_end,
        :cursor,
        :limit
      ])
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    {:ok, params}
  end
end
