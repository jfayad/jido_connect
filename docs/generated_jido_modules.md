# Generated Jido Modules

Each provider compiles to:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

These modules expose metadata through `jido_connect_projection/0` and delegate
execution to the core action, sensor, and plugin runtimes.
