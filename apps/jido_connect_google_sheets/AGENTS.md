# Google Sheets Connector Guidance

- Keep product-specific Sheets DSL, handlers, schemas, and normalized structs in
  this package. Shared Google OAuth, transport, scope, pagination, and account
  helpers belong in `jido_connect_google`.
- Keep DSL fragments grouped by capability: spreadsheets, values, sheet
  management, batch updates, and catalog packs.
- Keep the public Sheets client facade small. Put endpoint implementations in
  API-area modules instead of growing a large catch-all client.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave. Generated `google_api_sheets` remains a reference
  unless a later ADR changes the decision.
