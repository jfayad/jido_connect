# Jido Connect Google Search Console

Google Search Console provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Search Console-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Status

This scaffold declares the provider package, user OAuth profile, Search Console
scope resolver, generated Jido plugin shell, and shared Google transport
boundaries. Site, Search Analytics, sitemap, URL Inspection, catalog pack, and
trigger work is intentionally split into later implementation slices.

## OAuth Scopes

The provider declares the shared Google identity scopes plus Search Console
product scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/webmasters.readonly`
- `https://www.googleapis.com/auth/webmasters`

Read-only operations should use `webmasters.readonly` when possible. Site and
sitemap mutations should require `webmasters`.

## API Boundaries

- Webmasters v3 traffic should use
  `Jido.Connect.Google.SearchConsole.Client.Transport.webmasters_request/1`.
- Search Console v1 traffic, including URL Inspection, should use
  `Jido.Connect.Google.SearchConsole.Client.Transport.search_console_request/1`.

Both request builders delegate to `Jido.Connect.Google.Transport` and are
configurable through application environment for tests.

## Tool Surface

No Search Console actions or triggers are exposed by the scaffold yet. The
generated plugin and provider metadata are present so later tasks can add site,
Search Analytics, sitemap, URL Inspection, and catalog-pack action families
without changing package wiring.

## Query Shape

Search Analytics dimensions, filters, date ranges, aggregation type, and data
state are provider-specific Search Console contracts. Keep those mappings in
this package rather than adding a generic query DSL to `jido_connect` core.

The Search Analytics request shape is intentionally close to Analytics report
request conventions where the Google APIs overlap, so host code can reuse
date-range and reporting UX patterns without core-level query translation.

## Tool Availability

Generated plugin availability is available from the scaffold and will report
one entry per generated action or trigger as those tools are added:

```elixir
Jido.Connect.Google.SearchConsole.Plugin.tool_availability(%{connection: connection})
```
