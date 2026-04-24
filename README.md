# Jido Connect

Umbrella for Jido's integration/connectivity framework.

The public core entrypoint is `Jido.Connect`. The first provider app is
`jido_connect_github`, exposed as `Jido.Connect.GitHub`.

Current slice:

- Zoi-backed top-level contracts in `apps/jido_connect/lib/jido_connect/jido_connect.ex`
- Spark DSL extension under `apps/jido_connect/lib/jido_connect/dsl/`
- GitHub integration app at `apps/jido_connect_github`
- GitHub actions for `github.issue.list` and `github.issue.create`
- GitHub poll trigger contract for `github.issue.new`

See `docs/github_end_to_end.md` for the local demo and live integration testing
plan.

Copy `.env.example` to `.env` for local ngrok and GitHub credentials. `.env` is
ignored by git.

The previous Phoenix demo host is intentionally not part of this umbrella yet;
this first move keeps the umbrella to only `jido_connect` and
`jido_connect_github`.
