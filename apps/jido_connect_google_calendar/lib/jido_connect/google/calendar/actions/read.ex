defmodule Jido.Connect.Google.Calendar.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendar_list_scope "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  actions do
    action :list_calendars do
      id("google.calendar.calendar.list")
      resource(:calendar)
      verb(:list)
      data_classification(:personal_data)
      label("List calendars")
      description("List calendars visible in the user's Google Calendar list.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.ListCalendars)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendar_list_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:fields, :string)
        field(:min_access_role, :string, enum: ["freeBusyReader", "reader", "writer", "owner"])

        field(:show_deleted, :boolean, default: false)
        field(:show_hidden, :boolean, default: false)
        field(:sync_token, :string)
      end

      output do
        field(:calendars, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
      end
    end

    action :list_events do
      id("google.calendar.event.list")
      resource(:event)
      verb(:list)
      data_classification(:personal_data)
      label("List events")
      description("List Google Calendar events for a calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.ListEvents)
      effect(:read)

      access do
        auth(:user)
        scopes([@events_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:page_size, :integer, default: 250)
        field(:page_token, :string)
        field(:fields, :string)
        field(:time_min, :string)
        field(:time_max, :string)
        field(:time_zone, :string)
        field(:updated_min, :string)
        field(:q, :string)
        field(:single_events, :boolean, default: true)
        field(:show_deleted, :boolean, default: false)
        field(:show_hidden_invitations, :boolean, default: false)
        field(:order_by, :string, enum: ["startTime", "updated"])
        field(:sync_token, :string)
        field(:max_attendees, :integer)
        field(:event_types, {:array, :string})
      end

      output do
        field(:events, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
      end
    end

    action :get_event do
      id("google.calendar.event.get")
      resource(:event)
      verb(:get)
      data_classification(:personal_data)
      label("Get event")
      description("Fetch a Google Calendar event by calendar id and event id.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.GetEvent)
      effect(:read)

      access do
        auth(:user)
        scopes([@events_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:event_id, :string, required?: true, example: "event123")
        field(:fields, :string)
        field(:time_zone, :string)
        field(:max_attendees, :integer)
      end

      output do
        field(:event, :map)
      end
    end
  end
end
