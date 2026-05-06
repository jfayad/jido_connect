defmodule Jido.Connect.Google.Calendar.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Calendar.{Calendar, Client, Event}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_calendar,
      :google_calendar_api_base_url,
      "https://calendar.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_calendar, :google_calendar_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "lists calendars" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/users/me/calendarList"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
      assert conn.query_params["maxResults"] == "50"
      assert conn.query_params["showHidden"] == "true"
      assert conn.query_params["showDeleted"] == "false"
      assert conn.query_params["fields"] =~ "items(id,summary"

      Req.Test.json(conn, %{
        "items" => [
          %{
            "id" => "primary",
            "summary" => "Primary Calendar",
            "timeZone" => "America/Chicago",
            "primary" => true,
            "accessRole" => "owner"
          }
        ],
        "nextSyncToken" => "calendar-sync"
      })
    end)

    assert {:ok, %{calendars: [%Calendar{} = calendar], next_sync_token: "calendar-sync"}} =
             Client.list_calendars(
               %{page_size: 50, show_hidden: true, show_deleted: false},
               "token"
             )

    assert calendar.calendar_id == "primary"
    assert calendar.primary?
  end

  test "returns provider errors for malformed calendar list items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/users/me/calendarList"

      Req.Test.json(conn, %{
        "items" => [
          %{"summary" => "Missing id"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_calendars(%{}, "token")
  end

  test "lists events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/calendars/primary/events"
      assert conn.query_params["maxResults"] == "10"
      assert conn.query_params["singleEvents"] == "true"
      assert conn.query_params["showDeleted"] == "false"
      assert conn.query_params["timeMin"] == "2026-05-06T00:00:00Z"
      assert conn.query_params["timeMax"] == "2026-05-07T00:00:00Z"
      assert conn.query_params["fields"] =~ "nextSyncToken,items"

      Req.Test.json(conn, %{
        "items" => [
          %{
            "id" => "event123",
            "status" => "confirmed",
            "summary" => "Planning",
            "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
            "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
          }
        ],
        "nextPageToken" => "events-next"
      })
    end)

    assert {:ok, %{events: [%Event{} = event], next_page_token: "events-next"}} =
             Client.list_events(
               %{
                 calendar_id: "primary",
                 page_size: 10,
                 single_events: true,
                 show_deleted: false,
                 time_min: "2026-05-06T00:00:00Z",
                 time_max: "2026-05-07T00:00:00Z"
               },
               "token"
             )

    assert event.event_id == "event123"
    assert event.calendar_id == "primary"
    assert event.summary == "Planning"
  end

  test "gets events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/calendars/primary/events/event123"
      assert conn.query_params["maxAttendees"] == "10"
      assert conn.query_params["timeZone"] == "America/Chicago"
      assert conn.query_params["fields"] =~ "id,iCalUID,status"

      Req.Test.json(conn, %{
        "id" => "event123",
        "status" => "confirmed",
        "summary" => "Planning",
        "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
        "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
      })
    end)

    assert {:ok, %Event{} = event} =
             Client.get_event(
               %{
                 calendar_id: "primary",
                 event_id: "event123",
                 max_attendees: 10,
                 time_zone: "America/Chicago"
               },
               "token"
             )

    assert event.event_id == "event123"
    assert event.calendar_id == "primary"
  end

  test "returns provider errors for malformed event responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/calendars/primary/events/event123"

      Req.Test.json(conn, %{
        "summary" => "Missing id"
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} =
             Client.get_event(%{calendar_id: "primary", event_id: "event123"}, "token")
  end
end
