# Google Search Console Connector Guidance

- Keep product-specific Search Console DSL, handlers, schemas, normalized
  structs, and tests in this package. Shared Google OAuth, transport, scope,
  pagination, and account helpers belong in `jido_connect_google`.
- Keep Webmasters v3 operations and Search Console v1 URL Inspection concerns
  separated into focused client modules as they are added.
- Treat Search Analytics dimensions, date ranges, filters, aggregation type,
  and data state as provider-specific contracts. Reuse Analytics report request
  patterns where they fit, but do not add a generic report-query DSL to
  `jido_connect` core.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave.
