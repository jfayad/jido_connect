defmodule Jido.Connect.Calcom.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calcom.{Booking, EventType, Normalizer, Webhook}

  test "normalizes event type payloads" do
    assert {:ok, %EventType{id: 1, slug: "30min", title: "30 Min", length_in_minutes: 30}} =
             Normalizer.event_type(%{
               "id" => 1,
               "slug" => "30min",
               "title" => "30 Min",
               "length" => 30
             })
  end

  test "normalizes event type with metadata fields" do
    assert {:ok,
            %EventType{
              hidden: true,
              is_instant_event: false,
              metadata: %{scheduling_type: "round_robin", currency: "USD"}
            }} =
             Normalizer.event_type(%{
               "id" => 5,
               "slug" => "round",
               "hidden" => true,
               "schedulingType" => "round_robin",
               "currency" => "USD"
             })
  end

  test "rejects invalid event type payloads" do
    assert {:error, :invalid_event_type_payload} = Normalizer.event_type(:bad)
  end

  test "normalizes booking payloads" do
    assert {:ok,
            %Booking{
              uid: "booking-1",
              title: "Team Sync",
              status: "accepted",
              start: "2026-06-01T10:00:00Z",
              duration: 30
            }} =
             Normalizer.booking(%{
               "uid" => "booking-1",
               "title" => "Team Sync",
               "status" => "accepted",
               "startTime" => "2026-06-01T10:00:00Z",
               "duration" => 30
             })
  end

  test "normalizes booking with cancellation and rescheduling metadata" do
    assert {:ok,
            %Booking{
              uid: "booking-2",
              cancellation_reason: "conflict",
              metadata: %{recurring_booking_uid: "recur-1"}
            }} =
             Normalizer.booking(%{
               "uid" => "booking-2",
               "cancellationReason" => "conflict",
               "recurringBookingUid" => "recur-1"
             })
  end

  test "rejects invalid booking payloads" do
    assert {:error, :invalid_booking_payload} = Normalizer.booking(:bad)
  end

  test "normalizes webhook payloads" do
    assert {:ok,
            %Webhook{
              id: 1,
              subscriber_url: "https://example.com/hook",
              active: true,
              triggers: ["BOOKING_CREATED"]
            }} =
             Normalizer.webhook(%{
               "id" => 1,
               "subscriberUrl" => "https://example.com/hook",
               "active" => true,
               "triggers" => ["BOOKING_CREATED"]
             })
  end

  test "rejects invalid webhook payloads" do
    assert {:error, :invalid_webhook_payload} = Normalizer.webhook(:bad)
  end

  test "normalizes list event types response" do
    assert {:ok, [%EventType{id: 1}, %EventType{id: 2}]} =
             Normalizer.event_types(%{
               "data" => [
                 %{"id" => 1, "slug" => "a"},
                 %{"id" => 2, "slug" => "b"}
               ]
             })
  end

  test "rejects invalid list event types response" do
    assert {:error, :invalid_event_type_payload} = Normalizer.event_types(:bad)
    assert {:error, :invalid_event_type_collection} = Normalizer.event_types(%{"data" => :bad})
  end

  test "normalizes list bookings response with pagination" do
    assert {:ok, %{bookings: [%Booking{uid: "b1"}], next_cursor: "next", has_more: true}} =
             Normalizer.bookings(%{
               "data" => [%{"uid" => "b1"}],
               "pagination" => %{
                 "nextCursor" => "next",
                 "hasMore" => true
               }
             })
  end

  test "rejects invalid list bookings response" do
    assert {:error, :invalid_booking_payload} = Normalizer.bookings(:bad)
    assert {:error, :invalid_booking_collection} = Normalizer.bookings(%{"data" => :bad})
  end

  test "normalizes list webhooks response" do
    assert {:ok, [%Webhook{id: 1}]} =
             Normalizer.webhooks(%{
               "data" => [%{"id" => 1}]
             })
  end

  test "rejects invalid list webhooks response" do
    assert {:error, :invalid_webhook_payload} = Normalizer.webhooks(:bad)
  end
end
