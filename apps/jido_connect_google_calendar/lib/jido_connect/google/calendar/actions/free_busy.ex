defmodule Jido.Connect.Google.Calendar.Actions.FreeBusy do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @freebusy_scope "https://www.googleapis.com/auth/calendar.freebusy"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  actions do
    action :query_free_busy do
      id("google.calendar.freebusy.query")
      resource(:calendar)
      verb(:get)
      data_classification(:personal_data)
      label("Query freebusy")
      description("Query Google Calendar free/busy windows for calendars or groups.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.QueryFreeBusy)
      effect(:read)

      access do
        auth(:user)
        scopes([@freebusy_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_ids, {:array, :string}, required?: true)
        field(:time_min, :string, required?: true)
        field(:time_max, :string, required?: true)
        field(:time_zone, :string)
        field(:group_expansion_max, :integer)
        field(:calendar_expansion_max, :integer)
      end

      output do
        field(:free_busy, :map)
      end
    end

    action :find_availability do
      id("google.calendar.availability.find")
      resource(:calendar)
      verb(:search)
      data_classification(:personal_data)
      label("Find availability")
      description("Find candidate free windows across Google Calendar free/busy results.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.FindAvailability)
      effect(:read)

      access do
        auth(:user)
        scopes([@freebusy_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_ids, {:array, :string}, required?: true)
        field(:time_min, :string, required?: true)
        field(:time_max, :string, required?: true)
        field(:time_zone, :string)
        field(:group_expansion_max, :integer)
        field(:calendar_expansion_max, :integer)
        field(:duration_minutes, :integer, default: 30)
        field(:slot_step_minutes, :integer)
        field(:max_windows, :integer, default: 10)
      end

      output do
        field(:windows, {:array, :map})
        field(:free_busy, :map)
      end
    end
  end
end
