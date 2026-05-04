# Jido Connect MCP

`jido_connect_mcp` is a bridge package that exposes configured MCP servers as
Jido Connect tools. It delegates transport and protocol work to `jido_mcp` and
keeps Connect responsible for policy, generated Jido modules, and credential
boundaries.

This package is intentionally conservative: tools are called through explicit
Connect actions, endpoint and tool access is represented as scopes, and raw
MCP server credentials stay in host-owned `jido_mcp` endpoint configuration.

## Catalog Adapter

`Jido.Connect.MCP.CatalogAdapter` exposes the core Connect catalog as three
MCP-style tools for external agents:

- `jido_connect.catalog.search`
- `jido_connect.catalog.describe`
- `jido_connect.catalog.call`

The adapter is deliberately thin. Search and describe call
`Jido.Connect.Catalog.search_tools/2` and `describe_tool/2`. Execution calls
`Jido.Connect.Catalog.call_tool/4`, which delegates to the same runtime boundary
as generated Jido actions.

```elixir
Jido.Connect.MCP.CatalogAdapter.call(
  "jido_connect.catalog.search",
  %{query: "list mcp tools", filters: %{type: :action}},
  modules: [Jido.Connect.MCP]
)
```

Catalog calls still need the target provider runtime context and credential
lease. The MCP bridge endpoint credential is not reused as provider auth:

```elixir
Jido.Connect.MCP.CatalogAdapter.call(
  "jido_connect.catalog.call",
  %{
    tool_id: "mcp.tools.list",
    input: %{endpoint_id: "filesystem"}
  },
  modules: [Jido.Connect.MCP],
  runtime_opts: [
    context: context,
    credential_lease: lease
  ]
)
```

Optional rankers can be passed through adapter options. They receive sanitized
catalog metadata only and cannot bypass Connect auth, scope, policy, lease, or
confirmation checks.
