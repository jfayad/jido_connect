# Release Checklist

This is the baseline checklist before a release candidate or before starting
another large connector expansion pass. It is intentionally not Hex publishing
automation.

## Baseline Guard

1. Confirm the branch is clean except for intentional release-prep edits:

   ```sh
   git status --short --branch
   ```

2. Push the current baseline before starting another broad connector wave:

   ```sh
   git push origin main
   ```

   This repo can accumulate many small connector commits quickly; do not begin a
   new batch while `main` is significantly ahead of `origin/main`.

## Package Verification

Run the root quality gate from the umbrella root:

```sh
mix quality
```

If you need the expanded command list, it is:

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test --cover
```

Run docs separately:

```sh
MIX_ENV=docs mix docs
```

Each package also exposes a local quality alias when you want to isolate a
single app:

```sh
cd apps/jido_connect && mix quality
cd ../jido_connect_github && mix quality
cd ../jido_connect_slack && mix quality
cd ../jido_connect_mcp && mix quality
```

## Demo Host Verification

The Phoenix demo is not part of the packages, but it is the reference host for
OAuth, app-installation callbacks, ngrok URLs, webhooks, action execution, and
poll sensors.

```sh
cd dev/demo
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

## Package Inventory

The repo currently prepares these package apps:

- `apps/jido_connect`
- `apps/jido_connect_github`
- `apps/jido_connect_slack`
- `apps/jido_connect_mcp`

`dev/demo`, `.env`, `.secrets`, `_build`, `deps`, and generated docs are not
included in Hex packages.

## Publishing Notes

Hex publishing strategy is deliberately deferred. When that strategy is chosen,
publish `jido_connect` first, then provider packages that depend on it. Keep the
release task as a checklist until package ownership, versioning, and Git/GitHub
dependency guidance are final.
