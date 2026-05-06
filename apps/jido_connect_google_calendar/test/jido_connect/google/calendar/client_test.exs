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

  test "creates events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/calendars/primary/events"
      assert conn.query_params["sendUpdates"] == "all"
      assert conn.query_params["conferenceDataVersion"] == "1"
      assert conn.query_params["fields"] =~ "id,iCalUID,status"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "summary" => "Planning",
               "start" => %{
                 "dateTime" => "2026-05-06T09:00:00-05:00",
                 "timeZone" => "America/Chicago"
               },
               "end" => %{
                 "dateTime" => "2026-05-06T10:00:00-05:00",
                 "timeZone" => "America/Chicago"
               },
               "attendees" => [
                 %{
                   "email" => "guest@example.com",
                   "responseStatus" => "accepted"
                 }
               ],
               "recurrence" => ["RRULE:FREQ=DAILY;COUNT=2"]
             }

      Req.Test.json(conn, %{
        "id" => "created123",
        "status" => "confirmed",
        "summary" => "Planning",
        "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
        "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
      })
    end)

    assert {:ok, %Event{} = event} =
             Client.create_event(
               %{
                 calendar_id: "primary",
                 summary: "Planning",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00",
                 time_zone: "America/Chicago",
                 attendees: [
                   %{email: "guest@example.com", response_status: "accepted"}
                 ],
                 recurrence: ["RRULE:FREQ=DAILY;COUNT=2"],
                 send_updates: "all",
                 conference_data_version: 1
               },
               "token"
             )

    assert event.event_id == "created123"
    assert event.calendar_id == "primary"
  end

  test "updates events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/calendars/primary/events/event123"
      assert conn.query_params["sendUpdates"] == "externalOnly"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "summary" => "Updated",
               "transparency" => "transparent"
             }

      Req.Test.json(conn, %{
        "id" => "event123",
        "status" => "confirmed",
        "summary" => "Updated",
        "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
        "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
      })
    end)

    assert {:ok, %Event{} = event} =
             Client.update_event(
               %{
                 calendar_id: "primary",
                 event_id: "event123",
                 summary: "Updated",
                 transparency: "transparent",
                 send_updates: "externalOnly"
               },
               "token"
             )

    assert event.event_id == "event123"
    assert event.summary == "Updated"
  end

  test "deletes events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/calendars/primary/events/event123"
      assert conn.query_params["sendUpdates"] == "all"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{calendar_id: "primary", event_id: "event123", deleted?: true}} =
             Client.delete_event(
               %{calendar_id: "primary", event_id: "event123", send_updates: "all"},
               "token"
             )
  end

  test "queries freebusy" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/freeBusy"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "timeMin" => "2026-05-06T08:00:00Z",
               "timeMax" => "2026-05-06T11:00:00Z",
               "timeZone" => "UTC",
               "items" => [
                 %{"id" => "primary"},
                 %{"id" => "team@example.com"}
               ]
             }

      Req.Test.json(conn, %{
        "timeMin" => "2026-05-06T08:00:00Z",
        "timeMax" => "2026-05-06T11:00:00Z",
        "calendars" => %{
          "primary" => %{
            "busy" => [
              %{
                "start" => "2026-05-06T09:00:00Z",
                "end" => "2026-05-06T10:00:00Z"
              }
            ]
          }
        }
      })
    end)

    assert {:ok,
            %Jido.Connect.Google.Calendar.FreeBusy{
              busy: [
                %{
                  calendar_id: "primary",
                  start: "2026-05-06T09:00:00Z",
                  end: "2026-05-06T10:00:00Z"
                }
              ]
            }} =
             Client.query_free_busy(
               %{
                 calendar_ids: ["primary", "team@example.com"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z",
                 time_zone: "UTC"
               },
               "token"
             )
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
