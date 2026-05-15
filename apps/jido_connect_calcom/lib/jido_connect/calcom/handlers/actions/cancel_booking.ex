defmodule Jido.Connect.Calcom.Handlers.Actions.CancelBooking do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Calcom.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, booking_uid} <- require_booking_uid(input),
         {:ok, body} <- cancel_body(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, booking} <-
           client.cancel_booking(
             %{booking_uid: booking_uid, body: body},
             ResourceHelpers.credential_token(credentials)
           ) do
      {:ok, %{booking: ResourceHelpers.public_map(booking)}}
    end
  end

  defp require_booking_uid(input) do
    case Data.get(input, :booking_uid) do
      value when is_binary(value) and value != "" ->
        {:ok, String.trim(value)}

      _other ->
        {:error,
         Error.validation("Cal.com booking UID must be a non-empty string",
           reason: :invalid_booking_uid,
           details: %{field: :booking_uid}
         )}
    end
  end

  defp cancel_body(input) do
    body = %{}

    body =
      case Data.get(input, :cancellation_reason) do
        nil -> body
        value -> Map.put(body, "cancellationReason", value)
      end

    body =
      case Data.get(input, :cancel_subsequent_bookings) do
        nil -> body
        value -> Map.put(body, "cancelSubsequentBookings", value)
      end

    body =
      case Data.get(input, :seat_uid) do
        nil -> body
        value -> Map.put(body, "seatUid", value)
      end

    {:ok, body}
  end
end
