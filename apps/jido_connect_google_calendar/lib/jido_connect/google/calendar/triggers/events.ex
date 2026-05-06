defmodule Jido.Connect.Google.Calendar.Triggers.Events do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  triggers do
    poll :event_changed do
      id("google.calendar.event.changed")
      resource(:event)
      verb(:watch)
      data_classification(:personal_data)
      label("Event changed")
      description("Poll Google Calendar event changes using Events incremental sync tokens.")
      interval_ms(300_000)
      checkpoint(:sync_token)
      dedupe(%{key: [:event_id, :updated]})
      handler(Jido.Connect.Google.Calendar.Handlers.Triggers.EventChangedPoller)

      access do
        auth(:user)
        scopes([@events_readonly_scope], resolver: @scope_resolver)
      end

      config do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:page_size, :integer, default: 250)
        field(:fields, :string)
        field(:time_zone, :string)
        field(:max_attendees, :integer)
        field(:single_events, :boolean, default: true)
        field(:event_types, {:array, :string})
      end

      signal do
        field(:event_id, :string)
        field(:calendar_id, :string)
        field(:status, :string)
        field(:change_type, :string)
        field(:summary, :string)
        field(:start, :string)
        field(:end, :string)
        field(:updated, :string)
        field(:event, :map)
      end
    end
  end
end
