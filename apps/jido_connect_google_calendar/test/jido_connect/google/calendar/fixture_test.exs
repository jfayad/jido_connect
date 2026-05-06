defmodule Jido.Connect.Google.Calendar.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Calendar.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes common Google Calendar event fixture" do
    payload = fixture!("event_common.json")

    assert {:ok, event} = Normalizer.event(payload, calendar_id: "primary")
    assert event.event_id == "event123"
    assert event.calendar_id == "primary"
    assert event.summary == "Planning"
    assert event.start == "2026-05-06T09:00:00-05:00"
    assert event.end == "2026-05-06T10:00:00-05:00"
    assert [%{email: "guest@example.com", response_status: "accepted"}] = event.attendees
  end

  test "normalizes edge Google Calendar freebusy fixture" do
    payload = fixture!("freebusy_edge.json")

    assert {:ok, free_busy} = Normalizer.free_busy(payload)
    assert [%{calendar_id: "primary", start: "2026-05-06T09:00:00Z"}] = free_busy.busy

    assert %{
             target_type: :calendar,
             target_id: "missing@example.com",
             domain: "global",
             reason: "notFound"
           } in free_busy.errors

    assert %{
             target_type: :group,
             target_id: "team@example.com",
             domain: "global",
             reason: "groupTooBig"
           } in free_busy.errors
  end

  defp fixture!(name) do
    "../../../fixtures/google_calendar/#{name}"
    |> Path.expand(__DIR__)
    |> ConnectorContracts.json_fixture!()
  end
end
