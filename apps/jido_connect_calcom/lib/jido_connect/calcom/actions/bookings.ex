defmodule Jido.Connect.Calcom.Actions.Bookings do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Calcom.ScopeResolver

  actions do
    action :list_bookings do
      id("calcom.bookings.list")
      resource(:booking)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Cal.com bookings")
      description("List Cal.com bookings with optional filters.")
      handler(Jido.Connect.Calcom.Handlers.Actions.ListBookings)
      effect(:read)

      access do
        auth(:api_key)
        scopes(["BOOKING_READ"], resolver: @scope_resolver)
      end

      input do
        field(:status, :string, example: "upcoming")

        field(:attendee_email, :string)
        field(:event_type_id, :integer)
        field(:after_start, :string)
        field(:before_end, :string)
        field(:cursor, :string)
        field(:limit, :integer, default: 50)
      end

      output do
        field(:bookings, {:array, :map})
        field(:next_cursor, :string)
        field(:has_more, :boolean)
      end
    end

    action :get_booking do
      id("calcom.bookings.get")
      resource(:booking)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get Cal.com booking")
      description("Get a Cal.com booking by UID.")
      handler(Jido.Connect.Calcom.Handlers.Actions.GetBooking)
      effect(:read)

      access do
        auth(:api_key)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:booking_uid, :string,
          required?: true,
          example: "abc-123-def"
        )
      end

      output do
        field(:booking, :map)
      end
    end

    action :cancel_booking do
      id("calcom.bookings.cancel")
      resource(:booking)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Cancel Cal.com booking")
      description("Cancel a Cal.com booking by UID.")
      handler(Jido.Connect.Calcom.Handlers.Actions.CancelBooking)
      effect(:external_write, confirmation: :always)

      access do
        auth(:api_key)
        scopes(["BOOKING_WRITE"], resolver: @scope_resolver)
      end

      input do
        field(:booking_uid, :string,
          required?: true,
          example: "abc-123-def"
        )

        field(:cancellation_reason, :string)
        field(:cancel_subsequent_bookings, :boolean)
        field(:seat_uid, :string)
      end

      output do
        field(:booking, :map)
      end
    end

    action :reschedule_booking do
      id("calcom.bookings.reschedule")
      resource(:booking)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Reschedule Cal.com booking")
      description("Reschedule a Cal.com booking by UID to a new time.")
      handler(Jido.Connect.Calcom.Handlers.Actions.RescheduleBooking)
      effect(:external_write, confirmation: :always)

      access do
        auth(:api_key)
        scopes(["BOOKING_WRITE"], resolver: @scope_resolver)
      end

      input do
        field(:booking_uid, :string,
          required?: true,
          example: "abc-123-def"
        )

        field(:start, :string,
          required?: true,
          example: "2026-06-01T10:00:00Z"
        )

        field(:rescheduling_reason, :string)
        field(:rescheduled_by, :string)
        field(:seat_uid, :string)
      end

      output do
        field(:booking, :map)
      end
    end
  end
end
