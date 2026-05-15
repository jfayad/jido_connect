defmodule Jido.Connect.Calcom.Client do
  @moduledoc "Cal.com API client boundary."

  alias Jido.Connect.Calcom.Client.{Bookings, EventTypes}

  defdelegate list_event_types(params, access_token), to: EventTypes
  defdelegate list_bookings(params, access_token), to: Bookings
  defdelegate get_booking(params, access_token), to: Bookings
  defdelegate cancel_booking(params, access_token), to: Bookings
  defdelegate reschedule_booking(params, access_token), to: Bookings
end
