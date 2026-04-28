# Generated Jido Modules

Each provider compiles to:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

These modules expose metadata through `jido_connect_projection/0` and delegate
execution to the core action, sensor, and plugin runtimes. Projections include
operation ids, resource/verb metadata, auth profile alternatives, policy
requirements, scopes, risk, confirmation, and generated module names.

Generated actions and poll sensors expect the host to pass either a resolved
`Jido.Connect.Connection` inside `Jido.Connect.Context`, or a
`Jido.Connect.ConnectionSelector` plus a `connection_resolver` callback. In both
cases raw credentials stay out of agent context; execution still requires a
short-lived `Jido.Connect.CredentialLease`.
