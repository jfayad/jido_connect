defmodule Jido.Connect.Calcom.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calcom.{Booking, EventType, Webhook}

  test "event type struct validates with Zoi" do
    event_type =
      EventType.new!(%{
        id: 1,
        slug: "30min",
        title: "30 Minute Meeting",
        length_in_minutes: 30
      })

    assert event_type.id == 1
    assert event_type.slug == "30min"
    assert event_type.title == "30 Minute Meeting"
    assert event_type.length_in_minutes == 30
    assert event_type.hidden == false
    assert event_type.is_instant_event == false
    assert event_type.metadata == %{}
  end

  test "event type struct defaults optional fields" do
    event_type = EventType.new!(%{id: 42})

    assert event_type.slug == nil
    assert event_type.hidden == false
    assert event_type.is_instant_event == false
    assert event_type.metadata == %{}
  end

  test "event type struct rejects missing required fields" do
    assert {:error, _error} = EventType.new(%{})
  end

  test "booking struct validates with Zoi" do
    booking =
      Booking.new!(%{
        uid: "booking-123",
        title: "Team Sync",
        status: "accepted"
      })

    assert booking.uid == "booking-123"
    assert booking.title == "Team Sync"
    assert booking.status == "accepted"
    assert booking.metadata == %{}
  end

  test "booking struct defaults optional fields" do
    booking = Booking.new!(%{uid: "abc"})

    assert booking.id == nil
    assert booking.status == nil
    assert booking.metadata == %{}
  end

  test "booking struct rejects missing required fields" do
    assert {:error, _error} = Booking.new(%{})
  end

  test "webhook struct validates with Zoi" do
    webhook =
      Webhook.new!(%{
        id: 1,
        subscriber_url: "https://example.com/webhook",
        active: true,
        triggers: ["BOOKING_CREATED", "BOOKING_CANCELLED"]
      })

    assert webhook.id == 1
    assert webhook.subscriber_url == "https://example.com/webhook"
    assert webhook.active == true
    assert webhook.triggers == ["BOOKING_CREATED", "BOOKING_CANCELLED"]
  end

  test "webhook struct defaults optional fields" do
    webhook = Webhook.new!(%{})

    assert webhook.active == false
    assert webhook.triggers == []
    assert webhook.metadata == %{}
  end
end
