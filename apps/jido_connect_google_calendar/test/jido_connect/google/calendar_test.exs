defmodule Jido.Connect.Google.CalendarTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Calendar

  defmodule FakeCalendarClient do
    def list_calendars(
          %{page_size: 100, show_deleted: false, show_hidden: false},
          "token"
        ) do
      {:ok,
       %{
         calendars: [
           Calendar.Calendar.new!(%{
             calendar_id: "primary",
             summary: "Primary Calendar",
             time_zone: "America/Chicago",
             primary?: true,
             access_role: "owner"
           })
         ],
         next_sync_token: "calendar-sync"
       }}
    end

    def list_events(
          %{
            calendar_id: "primary",
            page_size: 250,
            single_events: true,
            show_deleted: false,
            show_hidden_invitations: false
          },
          "token"
        ) do
      {:ok,
       %{
         events: [
           Calendar.Event.new!(%{
             event_id: "event123",
             calendar_id: "primary",
             summary: "Planning",
             start: "2026-05-06T09:00:00-05:00",
             end: "2026-05-06T10:00:00-05:00"
           })
         ],
         next_page_token: "events-next"
       }}
    end

    def get_event(%{calendar_id: "primary", event_id: "event123"}, "token") do
      {:ok,
       Calendar.Event.new!(%{
         event_id: "event123",
         calendar_id: "primary",
         summary: "Planning",
         start: "2026-05-06T09:00:00-05:00",
         end: "2026-05-06T10:00:00-05:00"
       })}
    end

    def create_event(
          %{
            calendar_id: "primary",
            summary: "Planning",
            start: "2026-05-06T09:00:00-05:00",
            end: "2026-05-06T10:00:00-05:00",
            all_day: false,
            attendees: [
              %{email: "guest@example.com", response_status: "accepted"}
            ],
            recurrence: ["RRULE:FREQ=DAILY;COUNT=2"]
          },
          "token"
        ) do
      {:ok,
       Calendar.Event.new!(%{
         event_id: "created123",
         calendar_id: "primary",
         summary: "Planning",
         start: "2026-05-06T09:00:00-05:00",
         end: "2026-05-06T10:00:00-05:00",
         attendees: [
           Calendar.Attendee.new!(%{
             email: "guest@example.com",
             response_status: "accepted"
           })
         ],
         recurrence: ["RRULE:FREQ=DAILY;COUNT=2"]
       })}
    end

    def update_event(
          %{calendar_id: "primary", event_id: "event123", summary: "Updated"},
          "token"
        ) do
      {:ok,
       Calendar.Event.new!(%{
         event_id: "event123",
         calendar_id: "primary",
         summary: "Updated",
         start: "2026-05-06T09:00:00-05:00",
         end: "2026-05-06T10:00:00-05:00"
       })}
    end

    def delete_event(
          %{calendar_id: "primary", event_id: "event123", send_updates: "all"},
          "token"
        ) do
      {:ok, %{calendar_id: "primary", event_id: "event123", deleted?: true}}
    end
  end

  test "declares Google Calendar provider metadata" do
    spec = Calendar.integration()

    assert spec.id == :google_calendar
    assert spec.package == :jido_connect_google_calendar
    assert spec.name == "Google Calendar"
    assert spec.category == :calendar
    assert spec.tags == [:google, :workspace, :calendar, :productivity]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.calendar.calendar.list",
             "google.calendar.event.list",
             "google.calendar.event.get",
             "google.calendar.event.create",
             "google.calendar.event.update",
             "google.calendar.event.delete"
           ]

    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes

    assert "https://www.googleapis.com/auth/calendar.calendarlist.readonly" in profile.optional_scopes

    assert "https://www.googleapis.com/auth/calendar.freebusy" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/calendar.events.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/calendar.events" in profile.optional_scopes

    assert Enum.find(spec.actions, &(&1.id == "google.calendar.calendar.list")).scope_resolver ==
             Jido.Connect.Google.Calendar.ScopeResolver

    delete_action = Enum.find(spec.actions, &(&1.id == "google.calendar.event.delete"))
    assert delete_action.risk == :destructive
    assert delete_action.confirmation == :always
  end

  test "invokes list calendars through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              calendars: [
                %{
                  calendar_id: "primary",
                  summary: "Primary Calendar",
                  time_zone: "America/Chicago",
                  primary?: true
                }
              ],
              next_sync_token: "calendar-sync"
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.calendar.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list events through injected client and lease" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:ok,
            %{
              events: [
                %{
                  event_id: "event123",
                  calendar_id: "primary",
                  summary: "Planning"
                }
              ],
              next_page_token: "events-next"
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.list",
               %{calendar_id: "primary"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get event through injected client and lease" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:ok,
            %{
              event: %{
                event_id: "event123",
                calendar_id: "primary",
                summary: "Planning"
              }
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.get",
               %{calendar_id: "primary", event_id: "event123"},
               context: context,
               credential_lease: lease
             )
  end

  test "calendar list accepts broader Calendar readonly scope" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/calendar.readonly"
        ]
      )

    assert {:ok, %{calendars: [%{calendar_id: "primary"}]}} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.calendar.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "event reads accept broader Calendar event write scope" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/calendar.events"
        ]
      )

    assert {:ok, %{event: %{event_id: "event123"}}} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.get",
               %{calendar_id: "primary", event_id: "event123"},
               context: context,
               credential_lease: lease
             )
  end

  test "calendar list requires CalendarList readonly scope" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [
                "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
              ]
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.calendar.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "event reads require Calendar events readonly scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/calendar.events.readonly"]
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.get",
               %{calendar_id: "primary", event_id: "event123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create event through injected client and lease" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:ok,
            %{
              event: %{
                event_id: "created123",
                calendar_id: "primary",
                summary: "Planning",
                attendees: [%{email: "guest@example.com"}],
                recurrence: ["RRULE:FREQ=DAILY;COUNT=2"]
              }
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 summary: "Planning",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00",
                 attendees: [
                   %{email: " guest@example.com ", response_status: "accepted"}
                 ],
                 recurrence: [" RRULE:FREQ=DAILY;COUNT=2 "]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update event through injected client and lease" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:ok, %{event: %{event_id: "event123", summary: "Updated"}}} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.update",
               %{calendar_id: "primary", event_id: "event123", summary: "Updated"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete event through injected client and lease" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:ok, %{result: %{calendar_id: "primary", event_id: "event123", deleted?: true}}} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.delete",
               %{calendar_id: "primary", event_id: "event123", send_updates: "all"},
               context: context,
               credential_lease: lease
             )
  end

  test "event write actions require Calendar event write scope" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/calendar.events"]
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "create event validates time ranges" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_event_time,
              details: %{field: :end}
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 start: "2026-05-06T10:00:00-05:00",
                 end: "2026-05-06T09:00:00-05:00"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "create event validates attendees" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_event_attendee,
              details: %{field: :email}
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00",
                 attendees: [%{display_name: "Missing email"}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "create event validates recurrence lines" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_event_recurrence,
              details: %{field: :recurrence}
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00",
                 recurrence: ["FREQ=DAILY"]
               },
               context: context,
               credential_lease: lease
             )
  end

  defp event_read_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/calendar.events.readonly"
    ]
  end

  defp event_write_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/calendar.events"
    ]
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_calendar_client: FakeCalendarClient},
        scopes: scopes
      })

    {context, lease}
  end
end
