defmodule Jido.Connect.Google.Calendar.Client do
  @moduledoc "Google Calendar API client facade."

  alias Jido.Connect.Google.Calendar.Client.{CalendarList, Events}

  defdelegate list_calendars(params, access_token), to: CalendarList
  defdelegate list_events(params, access_token), to: Events
  defdelegate get_event(params, access_token), to: Events
  defdelegate create_event(params, access_token), to: Events
  defdelegate update_event(params, access_token), to: Events
  defdelegate delete_event(params, access_token), to: Events
end
