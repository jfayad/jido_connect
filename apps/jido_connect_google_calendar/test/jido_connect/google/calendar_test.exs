defmodule Jido.Connect.Google.CalendarTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Calendar

  @calendar_action_modules [
    Jido.Connect.Google.Calendar.Actions.ListCalendars,
    Jido.Connect.Google.Calendar.Actions.ListEvents,
    Jido.Connect.Google.Calendar.Actions.GetEvent,
    Jido.Connect.Google.Calendar.Actions.CreateEvent,
    Jido.Connect.Google.Calendar.Actions.UpdateEvent,
    Jido.Connect.Google.Calendar.Actions.DeleteEvent,
    Jido.Connect.Google.Calendar.Actions.QueryFreeBusy,
    Jido.Connect.Google.Calendar.Actions.FindAvailability
  ]

  @calendar_dsl_fragments [
    Jido.Connect.Google.Calendar.Actions.Read,
    Jido.Connect.Google.Calendar.Actions.Write,
    Jido.Connect.Google.Calendar.Actions.FreeBusy,
    Jido.Connect.Google.Calendar.Triggers.Events
  ]

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

    def list_events(
          %{
            calendar_id: "primary",
            sync_token: "expired-sync",
            page_size: 250,
            single_events: true,
            show_deleted: true,
            show_hidden_invitations: false
          },
          "token"
        ) do
      {:error,
       Connect.Error.provider("Google API request failed",
         provider: :google,
         reason: :http_error,
         status: 410,
         details: %{message: "Sync token is no longer valid"}
       )}
    end

    def list_events(
          %{
            calendar_id: "primary",
            page_token: "page-2",
            sync_token: "paged-sync",
            page_size: 250,
            single_events: true,
            show_deleted: true,
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
             status: "confirmed",
             summary: "Planning duplicate",
             start: "2026-05-06T09:00:00-05:00",
             end: "2026-05-06T10:00:00-05:00",
             updated: "2026-05-06T12:00:00Z"
           }),
           Calendar.Event.new!(%{
             event_id: "event456",
             calendar_id: "primary",
             status: "cancelled",
             summary: "Cancelled",
             updated: "2026-05-06T12:05:00Z"
           })
         ],
         next_sync_token: "paged-next-sync"
       }}
    end

    def list_events(
          %{
            calendar_id: "primary",
            sync_token: "paged-sync",
            page_size: 250,
            single_events: true,
            show_deleted: true,
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
             status: "confirmed",
             summary: "Planning",
             start: "2026-05-06T09:00:00-05:00",
             end: "2026-05-06T10:00:00-05:00",
             updated: "2026-05-06T12:00:00Z"
           })
         ],
         next_page_token: "page-2"
       }}
    end

    def list_events(
          %{
            calendar_id: "primary",
            sync_token: "sync-1",
            page_size: 250,
            single_events: true,
            show_deleted: true,
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
             status: "confirmed",
             summary: "Planning",
             start: "2026-05-06T09:00:00-05:00",
             end: "2026-05-06T10:00:00-05:00",
             updated: "2026-05-06T12:00:00Z"
           })
         ],
         next_sync_token: "sync-2"
       }}
    end

    def list_events(
          %{
            calendar_id: "primary",
            page_size: 250,
            single_events: true,
            show_deleted: true,
            show_hidden_invitations: false
          },
          "token"
        ) do
      {:ok,
       %{
         events: [
           Calendar.Event.new!(%{
             event_id: "old-event",
             calendar_id: "primary",
             status: "confirmed",
             summary: "Existing",
             start: "2026-05-05T09:00:00-05:00",
             end: "2026-05-05T10:00:00-05:00",
             updated: "2026-05-05T12:00:00Z"
           })
         ],
         next_sync_token: "sync-1"
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
            summary: "Local",
            start: "2026-05-06T09:00:00",
            end: "2026-05-06T10:00:00",
            time_zone: "America/Chicago",
            all_day: false,
            attendees: [],
            recurrence: []
          },
          "token"
        ) do
      {:ok,
       Calendar.Event.new!(%{
         event_id: "local123",
         calendar_id: "primary",
         summary: "Local",
         start: "2026-05-06T09:00:00",
         end: "2026-05-06T10:00:00",
         start_time_zone: "America/Chicago",
         end_time_zone: "America/Chicago"
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

    def query_free_busy(
          %{
            calendar_ids: ["primary"],
            time_min: "2026-05-06T08:00:00Z",
            time_max: "2026-05-06T11:00:00Z"
          },
          "token"
        ) do
      {:ok,
       Calendar.FreeBusy.new!(%{
         time_min: "2026-05-06T08:00:00Z",
         time_max: "2026-05-06T11:00:00Z",
         calendars: %{
           "primary" => %{
             "busy" => [
               %{
                 "start" => "2026-05-06T09:00:00Z",
                 "end" => "2026-05-06T10:00:00Z"
               }
             ]
           }
         },
         busy: [
           %{
             calendar_id: "primary",
             start: "2026-05-06T09:00:00Z",
             end: "2026-05-06T10:00:00Z"
           }
         ]
       })}
    end

    def query_free_busy(
          %{
            calendar_ids: ["broken"],
            time_min: "2026-05-06T08:00:00Z",
            time_max: "2026-05-06T11:00:00Z"
          },
          "token"
        ) do
      {:ok,
       Calendar.FreeBusy.new!(%{
         time_min: "2026-05-06T08:00:00Z",
         time_max: "2026-05-06T11:00:00Z",
         calendars: %{
           "broken" => %{
             "errors" => [%{"domain" => "global", "reason" => "notFound"}],
             "busy" => []
           }
         },
         errors: [
           %{
             target_type: :calendar,
             target_id: "broken",
             domain: "global",
             reason: "notFound"
           }
         ]
       })}
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
             "google.calendar.event.delete",
             "google.calendar.freebusy.query",
             "google.calendar.availability.find"
           ]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes

    assert "https://www.googleapis.com/auth/calendar.calendarlist.readonly" in profile.optional_scopes

    assert "https://www.googleapis.com/auth/calendar.freebusy" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/calendar.events.freebusy" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/calendar.events.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/calendar.events" in profile.optional_scopes

    assert Enum.find(spec.actions, &(&1.id == "google.calendar.calendar.list")).scope_resolver ==
             Jido.Connect.Google.Calendar.ScopeResolver

    delete_action = Enum.find(spec.actions, &(&1.id == "google.calendar.event.delete"))
    assert delete_action.risk == :destructive
    assert delete_action.confirmation == :always

    assert {:ok,
            %{
              id: "google.calendar.event.changed",
              kind: :poll,
              checkpoint: :sync_token,
              dedupe: %{key: [:event_id, :updated]},
              scope_resolver: Jido.Connect.Google.Calendar.ScopeResolver
            }} =
             Connect.trigger(spec, "google.calendar.event.changed")
  end

  test "compiles generated Jido modules for actions, sensors, and plugin" do
    assert Application.get_env(:jido_connect_google_calendar, :jido_connect_providers) == [
             Calendar
           ]

    assert Calendar.jido_action_modules() == @calendar_action_modules
    assert Calendar.jido_sensor_modules() == [Jido.Connect.Google.Calendar.Sensors.EventChanged]
    assert Calendar.jido_plugin_module() == Jido.Connect.Google.Calendar.Plugin

    assert %Connect.Catalog.Manifest{
             id: :google_calendar,
             package: :jido_connect_google_calendar,
             generated_modules: %{
               actions: @calendar_action_modules,
               sensors: [Jido.Connect.Google.Calendar.Sensors.EventChanged],
               plugin: Jido.Connect.Google.Calendar.Plugin
             }
           } = Calendar.jido_connect_manifest()

    action_ids = Calendar.integration().actions |> Enum.map(& &1.id) |> MapSet.new()

    for module <- @calendar_action_modules do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)

      projection = module.jido_connect_projection()
      tool = module.to_tool()

      assert projection.module == module
      assert projection.action_id in action_ids
      assert module.operation_id() == projection.action_id
      assert module.name() == projection.name
      assert tool.name == projection.name
    end

    sensor = Jido.Connect.Google.Calendar.Sensors.EventChanged

    assert {:module, ^sensor} = Code.ensure_loaded(sensor)
    assert function_exported?(sensor, :handle_event, 2)
    assert sensor.name() == "google_calendar_event_changed"
    assert sensor.trigger_id() == "google.calendar.event.changed"
    assert sensor.signal_type() == "google.calendar.event.changed"

    assert %Jido.Plugin.Spec{
             name: "google_calendar",
             module: Jido.Connect.Google.Calendar.Plugin,
             actions: @calendar_action_modules
           } = Jido.Connect.Google.Calendar.Plugin.plugin_spec()

    assert Calendar.reader_pack().id == :google_calendar_reader
    assert Calendar.scheduler_pack().id == :google_calendar_scheduler

    assert Enum.map(Calendar.catalog_packs(), & &1.id) == [
             :google_calendar_reader,
             :google_calendar_scheduler
           ]
  end

  test "loads Calendar Spark DSL fragments" do
    for fragment <- @calendar_dsl_fragments do
      assert {:module, ^fragment} = Code.ensure_loaded(fragment)
      assert fragment.extensions() == [Jido.Connect.Dsl.Extension]
      assert fragment.opts() == [of: Jido.Connect]
      assert %{extensions: [Jido.Connect.Dsl.Extension]} = fragment.persisted()
      assert is_map(fragment.spark_dsl_config())

      assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
               fragment.validate_sections()
    end
  end

  test "resolves Calendar scopes for broad grants and operation shapes" do
    resolver = Jido.Connect.Google.Calendar.ScopeResolver

    assert resolver.required_scopes(
             %{id: "google.calendar.calendar.list"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/calendar"]}
           ) == ["https://www.googleapis.com/auth/calendar"]

    assert resolver.required_scopes(
             %{action_id: "google.calendar.freebusy.query"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/calendar.readonly"]}
           ) == ["https://www.googleapis.com/auth/calendar.readonly"]

    assert resolver.required_scopes(
             %{id: "google.calendar.availability.find"},
             %{},
             %{scopes: []}
           ) == ["https://www.googleapis.com/auth/calendar.events.freebusy"]

    assert resolver.required_scopes(
             %{id: "google.calendar.event.update"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/calendar"]}
           ) == ["https://www.googleapis.com/auth/calendar"]

    assert resolver.required_scopes(%{}, %{}, %{}) == [
             "https://www.googleapis.com/auth/calendar.events.readonly"
           ]
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
                 recurrence: [" RRULE:FREQ=DAILY;COUNT=2 "],
                 time_zone: "America/Chicago"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "create event accepts local datetimes when explicit time zone is provided" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:ok, %{event: %{event_id: "local123", start_time_zone: "America/Chicago"}}} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 summary: "Local",
                 start: "2026-05-06T09:00:00",
                 end: "2026-05-06T10:00:00",
                 time_zone: "America/Chicago"
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

  test "recurring timed events require an explicit time zone" do
    {context, lease} = context_and_lease(scopes: event_write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_event_time,
              details: %{field: :time_zone}
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00",
                 recurrence: ["RRULE:FREQ=DAILY;COUNT=2"]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes freebusy query through injected client and lease" do
    {context, lease} = context_and_lease(scopes: freebusy_scopes())

    assert {:ok,
            %{
              free_busy: %{
                time_min: "2026-05-06T08:00:00Z",
                time_max: "2026-05-06T11:00:00Z",
                busy: [
                  %{
                    calendar_id: "primary",
                    start: "2026-05-06T09:00:00Z",
                    end: "2026-05-06T10:00:00Z"
                  }
                ]
              }
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.freebusy.query",
               %{
                 calendar_ids: ["primary"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "freebusy actions accept legacy calendar.freebusy scope" do
    {context, lease} = context_and_lease(scopes: freebusy_legacy_scopes())

    assert {:ok, %{free_busy: %{time_min: "2026-05-06T08:00:00Z"}}} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.freebusy.query",
               %{
                 calendar_ids: ["primary"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "finds normalized availability windows" do
    {context, lease} = context_and_lease(scopes: freebusy_scopes())

    assert {:ok,
            %{
              windows: [
                %{
                  start: "2026-05-06T08:00:00Z",
                  end: "2026-05-06T08:30:00Z",
                  duration_minutes: 30
                },
                %{
                  start: "2026-05-06T08:30:00Z",
                  end: "2026-05-06T09:00:00Z",
                  duration_minutes: 30
                },
                %{
                  start: "2026-05-06T10:00:00Z",
                  end: "2026-05-06T10:30:00Z",
                  duration_minutes: 30
                }
              ]
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.availability.find",
               %{
                 calendar_ids: ["primary"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z",
                 duration_minutes: 30,
                 slot_step_minutes: 30,
                 max_windows: 3
               },
               context: context,
               credential_lease: lease
             )
  end

  test "availability rejects partial freebusy errors" do
    {context, lease} = context_and_lease(scopes: freebusy_scopes())

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :partial_response,
              details: %{errors: [%{target_id: "broken", reason: "notFound"}]}
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.availability.find",
               %{
                 calendar_ids: ["broken"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "freebusy actions require freebusy scope" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/calendar.events.freebusy"]
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.freebusy.query",
               %{
                 calendar_ids: ["primary"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "freebusy actions validate calendar ids" do
    {context, lease} = context_and_lease(scopes: freebusy_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_freebusy_request,
              details: %{field: :calendar_ids}
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.freebusy.query",
               %{
                 calendar_ids: ["  "],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "freebusy actions validate expansion limits" do
    {context, lease} = context_and_lease(scopes: freebusy_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_freebusy_request,
              details: %{field: :calendar_expansion_max, max: 50}
            }} =
             Connect.invoke(
               Calendar.integration(),
               "google.calendar.freebusy.query",
               %{
                 calendar_ids: ["primary"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z",
                 calendar_expansion_max: 51
               },
               context: context,
               credential_lease: lease
             )
  end

  test "event change poll initializes checkpoint without replaying history" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:ok, %{signals: [], checkpoint: "sync-1"}} =
             Connect.poll(
               Calendar.integration(),
               "google.calendar.event.changed",
               %{calendar_id: "primary"},
               context: context,
               credential_lease: lease
             )
  end

  test "event change poll emits normalized events and advances checkpoint" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:ok,
            %{
              signals: [
                %{
                  event_id: "event123",
                  calendar_id: "primary",
                  status: "confirmed",
                  change_type: "updated",
                  summary: "Planning",
                  updated: "2026-05-06T12:00:00Z",
                  event: %{event_id: "event123", summary: "Planning"}
                }
              ],
              checkpoint: "sync-2"
            }} =
             Connect.poll(
               Calendar.integration(),
               "google.calendar.event.changed",
               %{calendar_id: "primary"},
               context: context,
               credential_lease: lease,
               checkpoint: "sync-1"
             )
  end

  test "event change poll drains pages, dedupes events, and advances checkpoint" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:ok,
            %{
              signals: [
                %{
                  event_id: "event123",
                  change_type: "updated",
                  event: %{summary: "Planning"}
                },
                %{
                  event_id: "event456",
                  status: "cancelled",
                  change_type: "cancelled",
                  event: %{summary: "Cancelled"}
                }
              ],
              checkpoint: "paged-next-sync"
            }} =
             Connect.poll(
               Calendar.integration(),
               "google.calendar.event.changed",
               %{calendar_id: "primary"},
               context: context,
               credential_lease: lease,
               checkpoint: "paged-sync"
             )
  end

  test "event change poll surfaces expired sync tokens as checkpoint errors" do
    {context, lease} = context_and_lease(scopes: event_read_scopes())

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :checkpoint_expired,
              status: 410,
              details: %{checkpoint: "expired-sync"}
            }} =
             Connect.poll(
               Calendar.integration(),
               "google.calendar.event.changed",
               %{calendar_id: "primary"},
               context: context,
               credential_lease: lease,
               checkpoint: "expired-sync"
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

  defp freebusy_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/calendar.events.freebusy"
    ]
  end

  defp freebusy_legacy_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/calendar.freebusy"
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
