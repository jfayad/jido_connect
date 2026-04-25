# Jido Connect

Umbrella for Jido's integration/connectivity framework.

The public core entrypoint is `Jido.Connect`. The first provider app is
`jido_connect_github`, exposed as `Jido.Connect.GitHub`.

Current slice:

- Zoi-backed top-level contracts in `apps/jido_connect/lib/jido_connect/`
- Spark DSL extension under `apps/jido_connect/lib/jido_connect/dsl/`
- GitHub integration app at `apps/jido_connect_github`
- GitHub actions for `github.issue.list` and `github.issue.create`
- GitHub poll trigger contract for `github.issue.new`
- Generic ngrok tunnel helper: `mix jido.connect.ngrok`
- Local Phoenix demo host under `dev/demo`

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

Live GitHub App validation has covered app creation, app installation,
installation-token minting, generated issue creation/listing, issue cleanup,
and verified issue webhooks through ngrok.
