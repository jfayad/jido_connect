defmodule Jido.Connect.Calcom.Client.Response do
  @moduledoc "Cal.com response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Calcom.Client.Transport
  alias Jido.Connect.Calcom.Normalizer

  def handle_event_types_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.event_types/1, "Cal.com event types response was invalid")
  end

  def handle_event_types_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Cal.com event types response was invalid", body)
  end

  def handle_event_types_response(response), do: Transport.handle_error_response(response)

  def handle_list_bookings_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.bookings/1, "Cal.com bookings response was invalid")
  end

  def handle_list_bookings_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Cal.com bookings response was invalid", body)
  end

  def handle_list_bookings_response(response), do: Transport.handle_error_response(response)

  def handle_get_booking_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(
      body,
      fn b -> Normalizer.booking(Data.get(b, "data", b)) end,
      "Cal.com booking response was invalid"
    )
  end

  def handle_get_booking_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Cal.com booking response was invalid", body)
  end

  def handle_get_booking_response(response), do: Transport.handle_error_response(response)

  def handle_cancel_booking_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(
      body,
      fn b -> Normalizer.booking(Data.get(b, "data", b)) end,
      "Cal.com cancel booking response was invalid"
    )
  end

  def handle_cancel_booking_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Cal.com cancel booking response was invalid", body)
  end

  def handle_cancel_booking_response(response), do: Transport.handle_error_response(response)

  def handle_reschedule_booking_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(
      body,
      fn b -> Normalizer.booking(Data.get(b, "data", b)) end,
      "Cal.com reschedule booking response was invalid"
    )
  end

  def handle_reschedule_booking_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Cal.com reschedule booking response was invalid", body)
  end

  def handle_reschedule_booking_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end
end
