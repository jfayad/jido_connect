defmodule Jido.Connect.Calcom.Normalizer do
  @moduledoc "Normalizes Cal.com API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Calcom.{Booking, EventType, Webhook}

  @doc "Normalizes a Cal.com event type payload."
  def event_type(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      slug: Data.get(payload, "slug"),
      title: Data.get(payload, "title"),
      description: Data.get(payload, "description"),
      length_in_minutes: Data.get(payload, "length"),
      hidden: Data.get(payload, "hidden", false),
      is_instant_event: Data.get(payload, "isInstantEvent", false),
      owner_id: Data.get(payload, "ownerId"),
      booking_url: Data.get(payload, "bookingUrl"),
      seats_per_time_slot: Data.get(payload, "seatsPerTimeSlot"),
      team_id: Data.get(payload, "teamId"),
      metadata:
        %{
          scheduling_type: Data.get(payload, "schedulingType"),
          currency: Data.get(payload, "currency"),
          price: Data.get(payload, "price"),
          recurrence: Data.get(payload, "recurrence"),
          locations: Data.get(payload, "locations"),
          schedule_id: Data.get(payload, "scheduleId"),
          disable_cancelling: Data.get(payload, "disableCancelling"),
          disable_rescheduling: Data.get(payload, "disableRescheduling")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> EventType.new()
  end

  def event_type(_payload), do: {:error, :invalid_event_type_payload}

  @doc "Normalizes a Cal.com booking payload."
  def booking(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      uid: Data.get(payload, "uid"),
      title: Data.get(payload, "title"),
      description: Data.get(payload, "description"),
      status: Data.get(payload, "status"),
      start: Data.get(payload, "startTime"),
      end: Data.get(payload, "endTime"),
      duration: Data.get(payload, "duration"),
      location: Data.get(payload, "location"),
      event_type_id: Data.get(payload, "eventTypeId"),
      cancellation_reason: Data.get(payload, "cancellationReason"),
      rescheduling_reason: Data.get(payload, "reschedulingReason"),
      metadata:
        %{
          recurring_booking_uid: Data.get(payload, "recurringBookingUid"),
          rescheduled_from_uid: Data.get(payload, "rescheduledFrom"),
          cancelled_by_email: Data.get(payload, "cancelledByEmail"),
          guests: Data.get(payload, "guests"),
          attendees: Data.get(payload, "attendees"),
          hosts: Data.get(payload, "hosts"),
          event_type: Data.get(payload, "eventType"),
          booking_fields_responses: Data.get(payload, "bookingFieldsResponses")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Booking.new()
  end

  def booking(_payload), do: {:error, :invalid_booking_payload}

  @doc "Normalizes a Cal.com webhook payload."
  def webhook(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      subscriber_url: Data.get(payload, "subscriberUrl"),
      active: Data.get(payload, "active", false),
      triggers: Data.get(payload, "triggers", []),
      payload_template: Data.get(payload, "payloadTemplate"),
      metadata:
        %{
          user_id: Data.get(payload, "userId"),
          secret: Data.get(payload, "secret") != nil
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Webhook.new()
  end

  def webhook(_payload), do: {:error, :invalid_webhook_payload}

  @doc "Normalizes a list event types response."
  def event_types(payload) when is_map(payload) do
    normalize_items(Data.get(payload, "data", []), &event_type/1, :invalid_event_type_collection)
  end

  def event_types(_payload), do: {:error, :invalid_event_type_payload}

  @doc "Normalizes a list bookings response."
  def bookings(payload) when is_map(payload) do
    with {:ok, bookings} <-
           normalize_items(Data.get(payload, "data", []), &booking/1, :invalid_booking_collection) do
      {:ok,
       %{
         bookings: bookings,
         next_cursor: get_in(payload, ["pagination", "nextCursor"]),
         has_more: get_in(payload, ["pagination", "hasMore"]) || false
       }
       |> Data.compact()}
    end
  end

  def bookings(_payload), do: {:error, :invalid_booking_payload}

  @doc "Normalizes a list webhooks response."
  def webhooks(payload) when is_map(payload) do
    normalize_items(Data.get(payload, "data", []), &webhook/1, :invalid_webhook_collection)
  end

  def webhooks(_payload), do: {:error, :invalid_webhook_payload}

  defp normalize_items(items, normalizer, error)

  defp normalize_items(items, normalizer, _error) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case normalizer.(payload) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, err} -> {:halt, {:error, err}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_items(_items, _normalizer, error), do: {:error, error}
end
