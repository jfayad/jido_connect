# Jido Connect Usage Rules

Use `Jido.Connect` to define integration packages with the Spark DSL and to run
actions or poll triggers through the runtime authorization boundary.

## Authoring

- Define provider capabilities in one integration module with `use Jido.Connect`.
- Declare auth profiles, actions, triggers, schemas, scopes, scope resolvers, and
  handler modules in the DSL.
- Do not edit generated Jido action, sensor, or plugin modules directly.
- Put provider behavior in handler modules and provider clients.

## Runtime

- Host apps own durable connection records and credential storage.
- Host apps pass a `Jido.Connect.Context` and short-lived
  `Jido.Connect.CredentialLease` into generated Jido actions and sensors.
- Credential leases must expire and must match the context connection id.
- Raw credentials belong only in `CredentialLease.fields`.
- Plugin config should use a full connection or a resolver; a bare
  `connection_id` is not enough to mark a tool available.

## Errors And Observability

- Return `{:ok, value}` or `{:error, %Jido.Connect.Error.*Error{}}`.
- Convert public errors with `Jido.Connect.Error.to_map/1`.
- Use `Jido.Connect.Sanitizer.sanitize/2` for telemetry and transport payloads.
- Runtime telemetry events use `[:jido, :connect, :invoke | :poll, phase]`,
  where `phase` is `:start`, `:stop`, or `:exception`.
