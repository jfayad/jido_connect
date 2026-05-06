# Jido Connect Google Calendar

Google Calendar provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Calendar-specific DSL,
handlers, schemas, normalized structs, and tests in this package.

## Actions

Calendar actions will be added as the connector epic progresses.

## Triggers

Calendar triggers will be added as the connector epic progresses.

## Scopes

The connector prefers narrow Calendar scopes:

- `calendar.events.readonly` for event reads and polling.
- `calendar.events` for event creation, updates, and deletes.
- `calendar.freebusy` for free/busy and availability helpers.
