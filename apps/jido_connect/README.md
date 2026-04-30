# Jido Connect

`jido_connect` is the core package for authoring integration providers with a
Spark DSL and compiling them into concrete Jido actions, sensors, and plugins.

The package owns contracts and runtime boundaries only. Host applications own
durable connection storage, credential storage, audit storage, OAuth sessions,
and webhook HTTP ingress.

Core Zoi-backed contract modules live in individual files under
`lib/jido_connect/`, including `Jido.Connect.Spec`, `Jido.Connect.ActionSpec`,
`Jido.Connect.TriggerSpec`, `Jido.Connect.Context`,
`Jido.Connect.Connection`, `Jido.Connect.CredentialLease`,
`Jido.Connect.PolicyRequirement`, and `Jido.Connect.NamedSchema`.

Provider DSL modules use first-class sections for `integration`, `catalog`,
`schemas`, `auth`, `policies`, `actions`, and `triggers`. Generated projections
carry resource, verb, auth, policy, scope, risk, confirmation, and schema
metadata for host discovery and policy callbacks.

Large provider packages can split DSL declarations with `Spark.Dsl.Fragment`
and include them through `use Jido.Connect, fragments: [...]`; generated modules
still compile under the parent provider namespace.

New providers should use the canonical `access` and `effect` DSL forms. Legacy
operation fields are treated as compatibility inputs and should not be mixed
with the canonical form. Every action and trigger must declare `resource`,
`verb`, and `data_classification`.

## Installation

```elixir
def deps do
  [
    {:jido_connect, "~> 0.1.0"}
  ]
end
```

## Host Boundary

A host app creates a durable `Jido.Connect.Connection`, mints a short-lived
`Jido.Connect.CredentialLease`, then calls generated Jido modules with both
values in context. Raw credentials should never be placed in plugin config,
agent state, or generated module metadata.

The top-level runtime API accepts either a provider module or a compiled
`Jido.Connect.Spec`, so host code can stay close to the provider it is using:

```elixir
Jido.Connect.invoke(Jido.Connect.GitHub, "github.issue.list", %{repo: "org/repo"},
  context: context,
  credential_lease: lease
)
```

For host UI discovery, use `Jido.Connect.spec/1`, `actions/1`, `triggers/1`,
`auth_profiles/1`, or the richer `Jido.Connect.Catalog` APIs. `Catalog.discover/1`
returns provider entries; `Catalog.tools/1` returns a flattened action/trigger
catalog for search and tool pickers, including filters such as `:tag`,
`:resource`, `:verb`, `:auth_kind`, `:auth_profile`, and `:scope`.

Host apps can install only the provider packages they need. For example, a
Phoenix app that wants GitHub but not Slack should depend on
`jido_connect_github`; the provider package depends on `jido_connect` and
self-registers `Jido.Connect.GitHub` for catalog discovery. If Slack is not in
the host dependency graph, Slack is not compiled or listed by discovery.

Provider packages self-register catalog modules with application metadata:

```elixir
def application do
  [
    extra_applications: [:logger],
    env: [jido_connect_providers: [Jido.Connect.GitHub]]
  ]
end
```

`use Jido.Connect` generates the provider behavior callbacks and
`Jido.Connect.Catalog.Manifest` from the DSL. Connector authors should not
maintain a second manifest by hand; the compiled spec and generated projection
stay the source of truth.

For local development against the umbrella before Hex publishing, use explicit
path dependencies to the app folders:

```elixir
{:jido_connect, path: "../jido_connect/apps/jido_connect"},
{:jido_connect_github, path: "../jido_connect/apps/jido_connect_github"}
```

Once published, prefer the provider package directly:

```elixir
{:jido_connect_github, "~> 0.1"}
```

Manual catalog registration remains available for private providers:

```elixir
config :jido_connect, catalog_modules: [MyApp.Connectors.Internal]
```

Authenticated generated actions and sensors require both a connection and a
matching credential lease. The connection is durable host-owned metadata; the
lease is short-lived credential material and has a redacted `Inspect`
implementation so accidental logs do not print tokens.

`CredentialLease` is the portable runtime auth envelope for provider packages.
Use `Jido.Connect.CredentialLease.from_connection/3` when minting a lease so it
copies non-secret binding metadata from the durable connection: provider,
profile, tenant, owner, subject, and effective scopes. This works the same for
user-level OAuth grants, tenant/org GitHub App installations, Slack workspace
bots, system API keys, and future connector-specific auth shapes. Runtime
authorization validates that the lease is active, belongs to the connection, and
does not claim broader scopes than the durable connection.

`ConnectionSelector` is the matching portable lookup intent: it describes which
connection a host should resolve for per-user, tenant/org, installation, system,
or explicit connection flows. `Jido.Connect.Authorization` then applies the
shared runtime checks across generated actions, sensors, plugin availability,
and future package bridges.

Host-owned policy stays outside the package but can be passed at runtime with
`policy:`. Core normalizes policy denial to `:policy_denied` and plugin
availability to `:disabled_by_policy`.

Availability distinguishes user-actionable connection states from package or
host configuration bugs. Missing or disconnected connections report
`:connection_required`; scope gaps report `:missing_scopes`; resolver, policy,
or dynamic scope failures that are not auth failures report
`:configuration_error` with sanitized error metadata.

Catalog discovery is lenient by default so one broken connector does not hide
the rest of the catalog. Use `Jido.Connect.Catalog.discover_with_diagnostics/1`
in CI, demo apps, and admin surfaces when you need to show unavailable
connectors and their structured failure reasons.

Provider packages should normalize reusable runtime shapes into the core
Zoi-backed structs:

- `Jido.Connect.CredentialLease` for short-lived credential material.
- `Jido.Connect.ProviderResponse` for provider HTTP/error envelopes.
- `Jido.Connect.WebhookDelivery` for verified webhook deliveries.
- `Jido.Connect.ConnectorCapability` for catalog-facing feature metadata.

```elixir
Jido.Connect.GitHub.Actions.ListIssues.run(
  %{repo: "org/repo"},
  %{integration_context: context, credential_lease: lease}
)
```

## Generated Modules

Every `use Jido.Connect` provider compiles thin generated modules:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

Generated modules expose `jido_connect_projection/0` for stable host
introspection and delegate execution to `Jido.Connect` runtimes.

Poll sensors are operational generated modules: Jido schedules ticks, core
delegates to `Jido.Connect.poll/4`, and the runtime emits `Jido.Signal`s while
carrying the in-memory checkpoint forward.

Generated plugin subscriptions accept a shared `trigger_config` fallback or
per-trigger configs keyed by trigger id:

```elixir
Jido.Connect.GitHub.Plugin.subscriptions(
  %{
    trigger_configs: %{
      "github.issue.new" => %{repo: "org/repo"},
      "github.workflow_run.updated" => %{repo: "org/repo", branch: "main"}
    }
  },
  context
)
```

Webhook sensors are generated as metadata-only projections until a host delivery
contract is attached. Provider packages should verify signatures and normalize
webhook bodies with their pure webhook helper modules, then the host can route
the resulting `Jido.Connect.WebhookDelivery` or normalized signal into its own
HTTP, idempotency, and persistence flow. Calling a metadata-only generated
webhook sensor directly returns a structured execution error instead of silently
pretending the event was handled.
