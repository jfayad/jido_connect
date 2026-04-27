# Authoring Integrations

Provider packages use `use Jido.Connect` and declare integration metadata,
auth profiles, actions, and triggers. The Spark DSL compiles the declaration
into a `Jido.Connect.Spec` and generated Jido modules.

Generated modules are adapters. Provider business logic belongs in handler
modules referenced by the DSL.

## Provider Package Shape

A connector should stay narrow:

- `integration.ex` declares provider metadata, auth profiles, actions, triggers,
  scopes, and optional scope resolvers.
- `oauth.ex` wraps provider-specific OAuth exchange and credential lease shaping.
- `client.ex` owns provider HTTP paths and response normalization.
- `webhook.ex` owns provider webhook verification and signal normalization.
- handlers contain provider business logic and read credentials only from
  `CredentialLease.fields`.

Start a new package scaffold with:

```sh
mix jido.connect.gen.provider google_sheets
```

## Shared Core Helpers

- `Jido.Connect.OAuth` for authorization URLs, required secret lookup, and Req
  defaults.
- `Jido.Connect.Http` for bearer Req setup and provider error shaping.
- `Jido.Connect.Webhook` for HMAC verification, header lookup, duplicate checks,
  and JSON decoding.
- `Jido.Connect.Polling` for checkpoint params and latest checkpoint selection.
- `Jido.Connect.Catalog` for host-facing connector metadata derived from specs
  and generated projections.

## Discovering The Catalog

Host apps can configure installed providers once:

```elixir
config :jido_connect,
  catalog_modules: [Jido.Connect.GitHub, Jido.Connect.Slack]
```

Then browse them from code:

```elixir
Jido.Connect.Catalog.discover(query: "issue")
Jido.Connect.Catalog.discover(auth_kind: :oauth2)
Jido.Connect.Catalog.discover(tool: "github.issue.list")
```

For local inspection, use:

```sh
mix jido.connect.catalog --query issue
mix jido.connect.catalog --format json --query slack
```
