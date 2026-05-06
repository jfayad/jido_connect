# Jido Connect Google Calendar

Google Calendar provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Calendar-specific DSL,
handlers, schemas, normalized structs, and tests in this package.

## Actions

- `google.calendar.calendar.list`
- `google.calendar.event.list`
- `google.calendar.event.get`
- `google.calendar.event.create`
- `google.calendar.event.update`
- `google.calendar.event.delete`
- `google.calendar.freebusy.query`
- `google.calendar.availability.find`

## Triggers

- `google.calendar.event.changed`

The event-change poller initializes by draining `events.list` pages to capture a
`nextSyncToken` without replaying existing history. Later polls use that sync
token, emit normalized event-change signals, and advance the checkpoint.

## Catalog Packs

- `:google_calendar_reader` includes calendar/event reads, freebusy,
  availability, and event-change polling.
- `:google_calendar_scheduler` adds event create, update, and delete tools for
  scheduling workflows.

```elixir
Jido.Connect.Catalog.search_tools("calendar",
  modules: [Jido.Connect.Google.Calendar],
  packs: Jido.Connect.Google.Calendar.catalog_packs(),
  pack: :google_calendar_scheduler
)
```

## Scopes

The connector prefers narrow Calendar scopes:

- `calendar.calendarlist.readonly` for listing visible calendars.
- `calendar.events.readonly` for event reads and polling.
- `calendar.events` for event creation, updates, and deletes.
- `calendar.events.freebusy` or `calendar.freebusy` for free/busy and
  availability helpers.
