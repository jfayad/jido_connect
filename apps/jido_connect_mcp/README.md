# Jido Connect MCP

`jido_connect_mcp` is a bridge package that exposes configured MCP servers as
Jido Connect tools. It delegates transport and protocol work to `jido_mcp` and
keeps Connect responsible for policy, generated Jido modules, and credential
boundaries.

This package is intentionally conservative: tools are called through explicit
Connect actions, endpoint and tool access is represented as scopes, and raw
MCP server credentials stay in host-owned `jido_mcp` endpoint configuration.

## Catalog Plugin

Catalog search, description, and catalog-mediated execution now live in
`Jido.Connect.Catalog.Plugin`, not in an MCP-specific adapter. If an MCP bridge
or external agent needs a Connect tool catalog, expose the core plugin/actions:

- `connect.catalog.search` via `Jido.Connect.Catalog.Actions.SearchTools`
- `connect.catalog.describe` via `Jido.Connect.Catalog.Actions.DescribeTool`
- `connect.catalog.call` via `Jido.Connect.Catalog.Actions.CallTool`

Include `Jido.Connect.MCP` in the plugin config modules when MCP bridge tools
should be searchable:

```elixir
Jido.Connect.Catalog.Plugin.plugin_spec(%{
  modules: [Jido.Connect.MCP],
  packs: [
    Jido.Connect.Catalog.Pack.new!(%{
      id: "mcp_readonly",
      filters: %{provider: :mcp, type: :action},
      allowed_tools: ["mcp.tools.list"]
    })
  ]
})
```

Catalog calls still need the target provider runtime context and credential
lease. The MCP bridge endpoint credential is not reused as catalog/provider auth.
All execution still goes through `Jido.Connect.Catalog.call_tool/4`, which
delegates to the same runtime boundary as generated Jido actions.
