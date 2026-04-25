# Jido Connect Slack

`jido_connect_slack` is the Slack provider package for `jido_connect`.

It includes:

- `Jido.Connect.Slack`, a Spark-authored provider that compiles into Jido tools
- generated actions for listing conversations and posting messages
- OAuth v2 helpers in `Jido.Connect.Slack.OAuth`
- Slack Web API helpers in `Jido.Connect.Slack.Client`
- signed request verification and Events API helpers in `Jido.Connect.Slack.Webhook`

The Spark DSL declaration lives in `lib/jido_connect/slack/integration.ex`.
Provider handlers live under `lib/jido_connect/slack/handlers/`.

## Installation

```elixir
def deps do
  [
    {:jido_connect_slack, "~> 0.1.0"}
  ]
end
```

## OAuth

Slack apps use OAuth v2. Hosts own state, installation storage, and credential
storage. This package builds authorize URLs and exchanges callback codes:

```elixir
url =
  Jido.Connect.Slack.OAuth.authorize_url(
    client_id: "123.456",
    redirect_uri: "https://example.ngrok-free.app/integrations/slack/oauth/callback",
    state: "csrf-state",
    scopes: ["channels:read", "chat:write"]
  )

{:ok, token} =
  Jido.Connect.Slack.OAuth.exchange_code("code",
    client_id: "123.456",
    client_secret: "secret",
    redirect_uri: "https://example.ngrok-free.app/integrations/slack/oauth/callback"
  )
```

Hosts turn the token response into a durable `Jido.Connect.Connection` and a
short-lived `Jido.Connect.CredentialLease` before running generated actions.

## Webhooks

Use `Jido.Connect.Slack.Webhook.verify_request/4` from a Plug or Phoenix
controller with the raw request body and Slack signing secret. Verification
checks the `v0` HMAC signature and rejects timestamps outside the replay window.

Events API `url_verification` callbacks can be handled with
`Jido.Connect.Slack.Webhook.url_verification_challenge/1`.
