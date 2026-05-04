# Jido Connect Google

`jido_connect_google` is the shared Google foundation package for Google
provider packages in the `jido_connect` ecosystem.

It is intentionally not a product connector. Packages such as
`jido_connect_google_sheets`, `jido_connect_gmail`,
`jido_connect_google_drive`, and `jido_connect_google_calendar` should depend on
this package for common Google contracts and helpers.

This package owns:

- Google auth profile constants and metadata.
- Google account/profile normalization.
- OAuth authorization URL and token exchange helpers.
- Credential lease helpers for short-lived Google access tokens.
- Shared Google scope, pagination, transport, and error helpers.

This package does not own:

- Host credential storage.
- Host connection persistence.
- OAuth callback state persistence.
- Google product endpoint DSL declarations.
- Durable poll checkpoints or watch-channel storage.

## Installation

```elixir
def deps do
  [
    {:jido_connect_google, "~> 0.1.0"}
  ]
end
```

Most host applications should depend on a product package instead. Pull this
package directly only when building another Google provider package or custom
Google connector.

## Package Shape

Google product packages should keep product-specific endpoint logic in their
own package:

- Sheets logic belongs in `jido_connect_google_sheets`.
- Gmail logic belongs in `jido_connect_gmail`.
- Drive logic belongs in `jido_connect_google_drive`.
- Calendar logic belongs in `jido_connect_google_calendar`.

Shared Google contracts and helpers belong here when they are genuinely
reusable across product packages.

## Auth Profiles

The shared package models three Google auth profiles:

- `:user` for OAuth authorization-code connections.
- `:service_account` for server-owned Google service accounts.
- `:domain_delegated_service_account` for Workspace domain-wide delegation.

Only user OAuth token exchange and refresh helpers are implemented in the first
foundation slice. Service-account and domain-delegated profiles are modeled so
product packages can declare future support without pretending token minting is
complete.

```elixir
Jido.Connect.Google.auth_profiles()
#=> [:user, :service_account, :domain_delegated_service_account]

Jido.Connect.Google.AuthProfiles.fetch!(:user)
```

## User OAuth

Build a Google authorization URL:

```elixir
url =
  Jido.Connect.Google.OAuth.authorize_url(
    client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
    redirect_uri: "https://app.example.com/integrations/google/oauth/callback",
    state: state,
    scope: [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/spreadsheets.readonly"
    ],
    prompt: "consent"
  )
```

Exchange an authorization code:

```elixir
{:ok, token} =
  Jido.Connect.Google.OAuth.exchange_code(code,
    client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
    client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET"),
    redirect_uri: "https://app.example.com/integrations/google/oauth/callback"
  )
```

Refresh a token from host-owned durable credential storage:

```elixir
{:ok, token} =
  Jido.Connect.Google.OAuth.refresh_token(refresh_token,
    client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
    client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET")
  )
```

## Connections And Leases

Shape a durable, host-owned Google connection from userinfo/profile metadata:

```elixir
{:ok, connection} =
  Jido.Connect.Google.Connections.user_connection(
    %{
      "sub" => "google-account-id",
      "email" => "user@example.com",
      "email_verified" => true,
      "name" => "User Name"
    },
    tenant_id: "tenant_1",
    credential_ref: "vault:google:user:user@example.com",
    scopes: ["openid", "email", "profile"]
  )
```

Mint a short-lived credential lease from a refreshed access token:

```elixir
{:ok, lease} =
  Jido.Connect.Google.OAuth.credential_lease(connection, token)
```

The lease contains only runtime credential material, such as `:access_token`.
Refresh tokens stay in host-owned durable storage.

## Shared Helpers

Scope catalog:

```elixir
Jido.Connect.Google.Scopes.product(:sheets)
Jido.Connect.Google.Scopes.missing(granted_scopes, required_scopes)
```

Transport boundary:

```elixir
request = Jido.Connect.Google.Transport.request(access_token)
```

Pagination helpers:

```elixir
query = Jido.Connect.Google.Pagination.query(%{}, page_token: "next", page_size: 100)
```
