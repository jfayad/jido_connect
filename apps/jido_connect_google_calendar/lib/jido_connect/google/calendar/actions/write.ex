defmodule Jido.Connect.Google.Calendar.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @events_scope "https://www.googleapis.com/auth/calendar.events"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  actions do
    action :create_event do
      id("google.calendar.event.create")
      resource(:event)
      verb(:create)
      data_classification(:personal_data)
      label("Create event")
      description("Create a Google Calendar event.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.CreateEvent)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@events_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:event_id, :string)
        field(:summary, :string)
        field(:description, :string)
        field(:location, :string)
        field(:color_id, :string)
        field(:start, :string, required?: true)
        field(:end, :string, required?: true)
        field(:time_zone, :string)
        field(:start_time_zone, :string)
        field(:end_time_zone, :string)
        field(:all_day, :boolean, default: false)
        field(:attendees, {:array, :map})
        field(:recurrence, {:array, :string})
        field(:reminders, :map)
        field(:conference_data, :map)
        field(:conference_data_version, :integer)
        field(:attachments, {:array, :map})
        field(:supports_attachments, :boolean)
        field(:extended_properties, :map)
        field(:transparency, :string, enum: ["opaque", "transparent"])
        field(:visibility, :string, enum: ["default", "public", "private", "confidential"])
        field(:guests_can_invite_others, :boolean)
        field(:guests_can_modify, :boolean)
        field(:guests_can_see_other_guests, :boolean)
        field(:send_updates, :string, enum: ["all", "externalOnly", "none"])
        field(:max_attendees, :integer)
        field(:fields, :string)
      end

      output do
        field(:event, :map)
      end
    end

    action :update_event do
      id("google.calendar.event.update")
      resource(:event)
      verb(:update)
      data_classification(:personal_data)
      label("Update event")
      description("Patch a Google Calendar event.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.UpdateEvent)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@events_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:event_id, :string, required?: true, example: "event123")
        field(:summary, :string)
        field(:description, :string)
        field(:location, :string)
        field(:color_id, :string)
        field(:start, :string)
        field(:end, :string)
        field(:time_zone, :string)
        field(:start_time_zone, :string)
        field(:end_time_zone, :string)
        field(:all_day, :boolean, default: false)
        field(:attendees, {:array, :map})
        field(:recurrence, {:array, :string})
        field(:reminders, :map)
        field(:conference_data, :map)
        field(:conference_data_version, :integer)
        field(:attachments, {:array, :map})
        field(:supports_attachments, :boolean)
        field(:extended_properties, :map)
        field(:transparency, :string, enum: ["opaque", "transparent"])
        field(:visibility, :string, enum: ["default", "public", "private", "confidential"])
        field(:guests_can_invite_others, :boolean)
        field(:guests_can_modify, :boolean)
        field(:guests_can_see_other_guests, :boolean)
        field(:send_updates, :string, enum: ["all", "externalOnly", "none"])
        field(:max_attendees, :integer)
        field(:fields, :string)
      end

      output do
        field(:event, :map)
      end
    end

    action :delete_event do
      id("google.calendar.event.delete")
      resource(:event)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete event")
      description("Delete a Google Calendar event.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.DeleteEvent)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@events_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:event_id, :string, required?: true, example: "event123")
        field(:send_updates, :string, enum: ["all", "externalOnly", "none"])
      end

      output do
        field(:result, :map)
      end
    end
  end
end
