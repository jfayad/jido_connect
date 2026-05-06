defmodule Jido.Connect.Google.Calendar.Client.Params do
  @moduledoc "Google Calendar request parameter helpers."

  alias Jido.Connect.Data

  @default_calendar_fields [
    "id",
    "summary",
    "summaryOverride",
    "description",
    "location",
    "timeZone",
    "accessRole",
    "backgroundColor",
    "foregroundColor",
    "colorId",
    "selected",
    "hidden",
    "primary",
    "deleted",
    "defaultReminders",
    "notificationSettings"
  ]

  @default_event_fields [
    "id",
    "iCalUID",
    "status",
    "summary",
    "description",
    "location",
    "htmlLink",
    "creator",
    "organizer",
    "start",
    "end",
    "recurrence",
    "recurringEventId",
    "originalStartTime",
    "attendees",
    "attendeesOmitted",
    "hangoutLink",
    "conferenceData",
    "reminders",
    "attachments",
    "extendedProperties",
    "transparency",
    "visibility",
    "eventType",
    "created",
    "updated",
    "etag",
    "sequence"
  ]

  @doc "Default calendar-list entry fields used by read actions."
  def default_calendar_fields, do: Enum.join(@default_calendar_fields, ",")

  @doc "Default event fields used by read actions."
  def default_event_fields, do: Enum.join(@default_event_fields, ",")

  @doc "Builds query params for `calendarList.list`."
  def list_calendars_params(params) do
    %{
      maxResults: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, calendar_list_fields()),
      minAccessRole: Data.get(params, :min_access_role),
      showDeleted: Data.get(params, :show_deleted),
      showHidden: Data.get(params, :show_hidden),
      syncToken: Data.get(params, :sync_token)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.list`."
  def list_events_params(params) do
    %{
      maxResults: Data.get(params, :page_size, 250),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, event_list_fields()),
      timeMin: Data.get(params, :time_min),
      timeMax: Data.get(params, :time_max),
      timeZone: Data.get(params, :time_zone),
      updatedMin: Data.get(params, :updated_min),
      q: Data.get(params, :q),
      singleEvents: Data.get(params, :single_events),
      showDeleted: Data.get(params, :show_deleted),
      showHiddenInvitations: Data.get(params, :show_hidden_invitations),
      orderBy: Data.get(params, :order_by),
      syncToken: Data.get(params, :sync_token),
      maxAttendees: Data.get(params, :max_attendees),
      eventTypes: Data.get(params, :event_types)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.get`."
  def get_event_params(params) do
    %{
      fields: Data.get(params, :fields, default_event_fields()),
      timeZone: Data.get(params, :time_zone),
      maxAttendees: Data.get(params, :max_attendees)
    }
    |> Data.compact()
  end

  defp calendar_list_fields,
    do: "nextPageToken,nextSyncToken,items(#{default_calendar_fields()})"

  defp event_list_fields,
    do: "nextPageToken,nextSyncToken,items(#{default_event_fields()})"
end
