defmodule Jido.Connect.MCP do
  @moduledoc """
  MCP bridge integration authored with the `Jido.Connect` Spark DSL.

  This package treats MCP as a bridge: remote server credentials and transport
  config stay in host-owned `jido_mcp` endpoint configuration, while Connect
  models endpoint/tool policy and exposes generated Jido actions.
  """

  use Jido.Connect

  integration do
    id(:mcp)
    name("MCP")
    category(:tool_bridge)
    docs(["https://modelcontextprotocol.io"])
    metadata(%{package: :jido_connect_mcp, bridge?: true})
  end

  auth do
    api_key :endpoint do
      default?(true)
      owner(:tenant)
      subject(:mcp_endpoint)
      label("Host-configured MCP endpoint")
      fields([])
      scopes(["mcp:tools:list", "mcp:tools:call", "mcp:endpoint:*", "mcp:tool:*"])
    end
  end

  actions do
    action :list_tools do
      id("mcp.tools.list")
      label("List MCP tools")
      description("List tools from a configured MCP endpoint.")
      auth(:endpoint)
      scopes(["mcp:tools:list"])
      scope_resolver(Jido.Connect.MCP.ScopeResolver)
      mutation?(false)
      risk(:read)
      handler(Jido.Connect.MCP.Handlers.Actions.ListTools)

      input do
        field(:endpoint_id, :string, required?: true, example: "filesystem")
        field(:timeout, :integer)
      end

      output do
        field(:endpoint_id, :string)
        field(:tools, {:array, :map})
      end
    end

    action :call_tool do
      id("mcp.tool.call")
      label("Call MCP tool")
      description("Call an allowlisted tool on a configured MCP endpoint.")
      auth(:endpoint)
      scopes(["mcp:tools:call"])
      scope_resolver(Jido.Connect.MCP.ScopeResolver)
      mutation?(true)
      risk(:external_write)
      confirmation(:required_for_ai)
      handler(Jido.Connect.MCP.Handlers.Actions.CallTool)

      input do
        field(:endpoint_id, :string, required?: true, example: "filesystem")
        field(:tool_name, :string, required?: true, example: "read_text_file")
        field(:arguments, :map, default: %{})
        field(:timeout, :integer)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
