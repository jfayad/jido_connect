# Jido Connect MCP

`jido_connect_mcp` is a bridge package that exposes configured MCP servers as
Jido Connect tools. It delegates transport and protocol work to `jido_mcp` and
keeps Connect responsible for policy, generated Jido modules, and credential
boundaries.

This package is intentionally conservative: tools are called through explicit
Connect actions, endpoint and tool access is represented as scopes, and raw
MCP server credentials stay in host-owned `jido_mcp` endpoint configuration.
