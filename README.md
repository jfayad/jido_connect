# Jido Connect

Umbrella for Jido's integration/connectivity framework.

The public core entrypoint is `Jido.Connect`. The first provider app is
`jido_connect_github`, exposed as `Jido.Connect.GitHub`.

The repository is an umbrella for development and publishing, but host apps do
not need to depend on every connector. Each app under `apps/` is intended to be
a separate package. A Phoenix project that only wants GitHub should depend on
`jido_connect_github`; it brings in `jido_connect` as its core dependency and
does not compile Slack or MCP.

Current slice:

- Zoi-backed top-level contracts in `apps/jido_connect/lib/jido_connect/`
- Spark DSL extension under `apps/jido_connect/lib/jido_connect/dsl/`
- GitHub integration app at `apps/jido_connect_github`
- Slack integration app at `apps/jido_connect_slack`
- MCP bridge app at `apps/jido_connect_mcp`
- GitHub actions for `github.issue.list` and `github.issue.create`
- GitHub poll trigger contract for `github.issue.new`
- Slack actions for `slack.channel.list`, `slack.message.post`,
  `slack.message.update`, `slack.message.delete`, and `slack.file.upload`
- MCP actions for `mcp.tools.list` and `mcp.tool.call`
- Catalog discovery through `Jido.Connect.Catalog`
- Generic ngrok tunnel helper: `mix jido.connect.ngrok`
- Local Phoenix demo host under `dev/demo`

See `docs/architecture.md` for the package boundaries and connector-factory
shape.

See `docs/github_end_to_end.md` for the local demo and live integration testing
plan.

Copy `.env.example` to `.env` for local ngrok and GitHub credentials. `.env` is
ignored by git.

The Phoenix demo host is intentionally outside the package umbrella at
`dev/demo`. It depends on the local packages by path and gives us one place to
exercise OAuth callbacks, GitHub App setup callbacks, webhooks, and future
provider routes without turning every provider into a demo app.

Run the demo host:

```sh
cd dev/demo
mix deps.get
mix phx.server
```

In another shell, from the repo root:

```sh
mix jido.connect.ngrok --provider github --port 4000
```

Run the package quality gate:

```sh
mix quality
```

Live GitHub App validation has covered app creation, app installation,
installation-token minting, generated issue creation/listing, issue cleanup,
and verified issue webhooks through ngrok.

## Using One Connector In A Host App

After Hex publishing, a GitHub-only Phoenix app can use:

```elixir
def deps do
  [
    {:jido_connect_github, "~> 0.1"}
  ]
end
```

Do not also add `jido_connect_slack` unless that host should expose Slack tools.
The provider package registers itself through its application environment:

```elixir
def application do
  [
    extra_applications: [:logger],
    env: [jido_connect_providers: [Jido.Connect.GitHub]]
  ]
end
```

That lets catalog discovery find installed providers without a host-maintained
manifest:

```elixir
Jido.Connect.Catalog.discover()
#=> [%Jido.Connect.Catalog.Entry{id: :github, ...}]
```

If Slack is not in `deps/0`, Slack is not loaded and will not appear in the
catalog. Hosts can still opt into manual registration for private/local
connectors:

```elixir
config :jido_connect,
  catalog_modules: [MyApp.Connectors.Internal]
```

Use `Jido.Connect.Catalog.discover_with_diagnostics/1` in admin screens, CI, and
demo apps when a broken or missing connector should be visible as a diagnostic
instead of being silently skipped.

Before Hex publishing, use path dependencies from a sibling checkout when
testing a host app against this monorepo:

```elixir
def deps do
  [
    {:jido_connect, path: "../jido_connect/apps/jido_connect"},
    {:jido_connect_github, path: "../jido_connect/apps/jido_connect_github"}
  ]
end
```

Direct Git dependency syntax for individual apps should be finalized with the
package release strategy; the reliable local development path today is an
explicit checkout plus path dependencies.
