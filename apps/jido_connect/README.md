# Jido Connect

`jido_connect` is the core package for authoring integration providers with a
Spark DSL and compiling them into concrete Jido actions, sensors, and plugins.

The package owns contracts and runtime boundaries only. Host applications own
durable connection storage, credential storage, audit storage, OAuth sessions,
and webhook HTTP ingress.

Core Zoi-backed contract modules live in individual files under
`lib/jido_connect/`, including `Jido.Connect.Spec`, `Jido.Connect.ActionSpec`,
`Jido.Connect.TriggerSpec`, `Jido.Connect.Context`,
`Jido.Connect.Connection`, and `Jido.Connect.CredentialLease`.

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

Authenticated generated actions and sensors require both a connection and a
matching credential lease. The connection is durable host-owned metadata; the
lease is short-lived credential material and has a redacted `Inspect`
implementation so accidental logs do not print tokens.

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
