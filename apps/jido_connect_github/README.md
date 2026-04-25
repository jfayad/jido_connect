# Jido Connect GitHub

`jido_connect_github` is the GitHub provider package for `jido_connect`.

It includes:

- `Jido.Connect.GitHub`, a Spark-authored provider that compiles into Jido tools
- GitHub issue actions and a poll sensor
- OAuth App helpers in `Jido.Connect.GitHub.OAuth`
- GitHub App helpers in `Jido.Connect.GitHub.AppAuth`
- REST client helpers in `Jido.Connect.GitHub.Client`
- Webhook verification and normalization in `Jido.Connect.GitHub.Webhook`

The Spark DSL declaration lives in
`lib/jido_connect/github/integration.ex`. Provider handlers live under
`lib/jido_connect/github/handlers/`.

## Installation

```elixir
def deps do
  [
    {:jido_connect_github, "~> 0.1.0"}
  ]
end
```

## GitHub App Flow

Hosts store the GitHub App private key path and installation id, then mint a
short-lived credential lease when a Jido tool runs:

```elixir
{:ok, lease} =
  Jido.Connect.GitHub.AppAuth.installation_credential_lease(
    installation_id,
    %{tenant_id: "tenant_1", actor: %{id: "user_1"}},
    connection_id: "conn_1"
  )
```

## Webhooks

Use `Jido.Connect.GitHub.Webhook.verify_request/3` from a Plug or Phoenix
controller before normalizing event payloads. The package verifies signatures
and produces signal-shaped maps; the host owns persistence and delivery dedupe.
