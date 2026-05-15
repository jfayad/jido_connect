# Jido Connect Cal.com

Cal.com provider package for Jido Connect.

This package provides a Cal.com integration for Jido Connect, supporting
event type discovery, booking management, and webhook triggers for the
Cal.com v2 API.

## Status

This package declares the provider package, API key and OAuth2 auth profiles,
Cal.com scope resolver, generated Jido actions, package-local transport
boundary, normalized Zoi-backed structs for event types/bookings/webhooks, and
curated catalog packs. Webhook lifecycle actions and triggers are intentionally
split into later Beadwork tasks.

## Normalized Structs

- `Jido.Connect.Calcom.EventType`
- `Jido.Connect.Calcom.Booking`
- `Jido.Connect.Calcom.Webhook`

## Auth Profiles

The provider supports two authentication profiles:

- **API key** (`:api_key`): Personal access token (`cal_`-prefixed) captured in
  the `:api_key` credential field and passed as a Bearer token. Recommended for
  development and CI.
- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
  PKCE. Requires Cal.com admin approval of the OAuth client.

## API Boundaries

All Cal.com API traffic uses
`Jido.Connect.Calcom.Client.Transport.api_request/2`, which builds bearer
requests against the configurable Cal.com v2 API base URL.

Cal.com requires a `cal-api-version` header that varies per endpoint. The
transport layer applies the correct version automatically based on the action
being invoked.

## Tool Surface

- `calcom.event_types.list`
- `calcom.bookings.list`
- `calcom.bookings.get`
- `calcom.bookings.cancel`
- `calcom.bookings.reschedule`

No Cal.com triggers are exposed yet. The generated plugin and provider
metadata are present so later tasks can add triggers without changing package
wiring.

## Catalog Packs

`Jido.Connect.Calcom.catalog_packs/0` returns storage-free catalog packs that
hosts can pass to the catalog boundary:

- `Jido.Connect.Calcom.reader_pack/0` exposes read-only tools: event type
  listing and booking queries.
- `Jido.Connect.Calcom.booking_pack/0` includes the reader tools plus booking
  cancel and reschedule actions.

Use packs with catalog search, description, and invocation:

```elixir
Jido.Connect.Catalog.search_tools("booking",
  modules: [Jido.Connect.Calcom],
  packs: Jido.Connect.Calcom.catalog_packs(),
  pack: :calcom_reader
)
```

## API Versioning

Cal.com v2 endpoints require a `cal-api-version` header, but the required
version differs per endpoint group. The connector stores and sends the correct
version per action:

| Endpoint Group       | Required Version |
|----------------------|-----------------|
| Event types          | `2024-06-14`    |
| Bookings (list)      | `2026-05-01`    |
| Bookings (get, cancel, reschedule) | `2026-02-25` |

## Tool Availability

Generated plugin availability is available from the package:

```elixir
Jido.Connect.Calcom.Plugin.tool_availability(%{connection: connection})
```
