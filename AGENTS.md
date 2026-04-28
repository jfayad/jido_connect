# Agent Guidance

This repository contains the `jido_connect` umbrella and a local Phoenix demo
host.

## Working Rules

- Prefer the existing Spark DSL and Zoi struct patterns.
- Keep generated Jido modules thin. They should carry metadata and delegate to
  `Jido.Connect` runtimes.
- Keep provider API logic in provider clients and handlers.
- Keep host-owned persistence, credential storage, and audit storage out of core
  package contracts.
- Use `Jido.Connect.Error` for normalized errors.
- Use `Jido.Connect.Sanitizer` before emitting telemetry or public payloads.
- Do not log or expose raw access tokens, refresh tokens, private keys, client
  secrets, signing secrets, or credential lease fields.

## Verification

From the umbrella root:

```sh
mix quality
```

From the demo app:

```sh
cd dev/demo
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Release and Hex publishing automation are intentionally out of scope for now.
