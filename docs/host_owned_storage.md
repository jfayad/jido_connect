# Host-Owned Storage

`jido_connect` intentionally does not ship Ecto schemas, migrations, storage
behaviours, or adapters.

Hosts own:

- durable connection records
- credential storage
- OAuth state/session persistence
- webhook delivery dedupe
- run and event audit history

The package contracts are `Jido.Connect.Connection`,
`Jido.Connect.ConnectionSelector`, `Jido.Connect.CredentialLease`,
`Jido.Connect.Run`, and `Jido.Connect.Event`.

`CredentialLease` is the portable credential handoff between host-owned storage
and any generated action, sensor, or bridge call. Provider packages mint leases
from OAuth token exchanges, app installation token creation, API keys, or
host-configured bridge credentials; handlers read only from `lease.fields`.

## Connection Ownership

`Connection` records describe durable grants owned by a host principal:

- `owner_type: :user` for per-user OAuth credentials.
- `owner_type: :tenant` for tenant-wide shared installs, such as a Slack bot.
- `owner_type: :installation` for app installation grants, such as GitHub App
  installations.
- `owner_type: :system` for app-controlled credentials.

`jido_connect` validates resolved connections, profiles, scopes, and short-lived
leases, but it does not decide whether an actor may use a shared credential.
That policy belongs to the host app.

## Connection Selectors

Use `ConnectionSelector` when the caller knows which kind of credential should
be used but the host still needs to load the durable connection:

```elixir
{:ok, selector} =
  Jido.Connect.ConnectionSelector.tenant_default(:slack, "tenant_1",
    profile: :bot,
    required_scopes: ["chat:write"]
  )
```

Generated Jido actions and sensors can receive a context with a
`connection_selector` plus a host resolver:

```elixir
Jido.Connect.Slack.Actions.PostMessage.run(params, %{
  integration_context: %Jido.Connect.Context{
    tenant_id: "tenant_1",
    actor: %{id: "user_1", type: :user},
    connection_selector: selector
  },
  connection_resolver: &MyApp.Connections.resolve!/1,
  credential_lease: lease
})
```

The resolver returns a `Jido.Connect.Connection`. The host still mints the
matching `CredentialLease` from its credential store. `CredentialLease.from_connection/3`
is the preferred constructor because it copies provider, profile, tenant,
owner, subject, and granted scopes from the durable connection.

Core then checks:

- the lease has not expired
- the connection id matches the lease
- the connection is connected
- the resolved connection matches the selector
- the connection profile is allowed for the operation
- the connection and effective lease scopes satisfy required scopes

If a lease carries its own scopes, the effective scopes are the intersection of
connection scopes and lease scopes. This lets hosts narrow a short-lived lease
without weakening the durable connection grant.

Plugin availability accepts the same selector/resolver pattern, so UIs can
show whether shared tenant or installation tools are available without exposing
raw credentials.
