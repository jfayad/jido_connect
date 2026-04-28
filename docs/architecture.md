# Architecture

`jido_connect` is a connector factory. The core package owns the shared
contracts and runtime boundary; provider packages normalize provider-specific
details into those contracts.

## Package Layers

The umbrella has three layers:

- `jido_connect` owns the Spark DSL, Zoi-backed contract structs, generated Jido
  adapters, authorization checks, catalog discovery, telemetry, and normalized
  runtime envelopes.
- Provider packages such as `jido_connect_github`, `jido_connect_slack`, and
  `jido_connect_mcp` own provider auth helpers, REST or bridge clients, webhook
  verification, scope resolvers, and handlers.
- `dev/demo` is a local host harness. It owns local callbacks, in-memory
  connections, credential lookup, webhook consoles, and action runners. It is
  not part of the published packages.

## Core Contracts

The base package should stay storage-free and provider-neutral. Its primary
contracts are:

- `Jido.Connect.Spec`, `AuthProfile`, `ActionSpec`, and `TriggerSpec` for the
  compiled integration declaration.
- `Jido.Connect.Connection` and `ConnectionSelector` for durable grant metadata
  and host-owned lookup intent.
- `Jido.Connect.CredentialLease` for short-lived credential material passed to a
  single action, sensor, or bridge call.
- `Jido.Connect.Context` for tenant, actor, connection, and selector data at
  execution time.
- `Jido.Connect.ProviderResponse`, `WebhookDelivery`, and
  `ConnectorCapability` for reusable normalized envelopes.
- `Jido.Connect.Run` and `Event` for host audit surfaces.

Providers should normalize into these structs instead of leaking raw provider
maps into shared APIs.

## Generated Jido Modules

Every `use Jido.Connect` provider compiles thin generated modules:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

Generated modules carry projection metadata and delegate to core runtimes. They
do not contain provider business logic, read raw credentials, or become a second
authoring surface.

## Authorization Flow

Action and sensor execution use one shared authorization path:

- resolve a `Context`
- resolve or validate a `Connection`
- require an active `CredentialLease`
- ensure the lease is bound to the connection
- ensure the connection profile is allowed for the operation
- resolve static and dynamic scopes
- execute the provider handler only after those checks pass

Provider packages may supply scope resolvers for input-dependent access rules,
such as Slack conversation types or GitHub App installation permissions.

## Provider Package Shape

A mature provider package should generally include:

- `integration.ex` for the DSL declaration and catalog capability metadata.
- `oauth.ex`, `app_auth.ex`, or equivalent auth helpers.
- `client.ex` for provider HTTP or bridge calls and error normalization.
- `webhook.ex` for signature verification and event normalization.
- `scope_resolver.ex` when scopes depend on inputs, config, or auth profile.
- handler modules under `handlers/` for action and trigger execution.

The base package provides reusable helpers for OAuth, HTTP, webhooks, polling,
catalog discovery, sanitization, errors, telemetry, and credential leases.

## Host Boundary

Hosts own persistence and policy:

- durable connection records
- encrypted credential storage
- OAuth state and callback sessions
- webhook delivery dedupe
- actor authorization for shared user, tenant, installation, or system grants
- audit storage

`jido_connect` validates the execution boundary, but it intentionally does not
ship storage behaviours, Ecto schemas, migrations, or permission policy.

## Catalog

`Jido.Connect.Catalog` turns provider modules into discoverable entries with
auth profiles, tools, generated modules, and high-level capabilities. Provider
metadata can add explicit capabilities such as setup flows, webhook support, or
MCP bridge support while the base package derives auth, action, and trigger
capabilities from the DSL.
