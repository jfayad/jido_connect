defmodule Jido.Connect.Calcom.Handlers.Actions.RescheduleBooking do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Calcom.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, booking_uid} <- require_booking_uid(input),
         {:ok, start} <- require_start(input),
         {:ok, body} <- reschedule_body(input, start),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, booking} <-
           client.reschedule_booking(
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

  defp require_start(input) do
    case Data.get(input, :start) do
      value when is_binary(value) and value != "" ->
        {:ok, String.trim(value)}

      _other ->
        {:error,
         Error.validation("Cal.com reschedule start time is required",
           reason: :invalid_reschedule_start,
           details: %{field: :start}
         )}
    end
  end

  defp reschedule_body(input, start) do
    body = %{"start" => start}

    body =
      case Data.get(input, :rescheduling_reason) do
        nil -> body
        value -> Map.put(body, "reschedulingReason", value)
      end

    body =
      case Data.get(input, :rescheduled_by) do
        nil -> body
        value -> Map.put(body, "rescheduledBy", value)
      end

    body =
      case Data.get(input, :seat_uid) do
        nil -> body
        value -> Map.put(body, "seatUid", value)
      end

    {:ok, body}
  end
end
