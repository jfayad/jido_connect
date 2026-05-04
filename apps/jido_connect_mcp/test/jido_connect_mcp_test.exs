defmodule Jido.Connect.MCPTest do
  use ExUnit.Case

  alias Jido.Connect

  defmodule FakeMCPClient do
    def list_tools(:filesystem) do
      {:ok,
       %{
         data: %{
           "tools" => [
             %{
               name: "read_text_file",
               description: "Read a text file without a timeout",
               inputSchema: %{"type" => "object"}
             }
           ]
         }
       }}
    end

    def list_tools(:filesystem, opts) do
      assert opts[:timeout] == 1_000

      {:ok,
       %{
         status: :ok,
         data: %{
           "tools" => [
             %{
               "name" => "read_text_file",
               "description" => "Read a text file",
               "inputSchema" => %{"type" => "object"},
               "annotations" => %{"readOnlyHint" => true}
             }
           ]
         }
       }}
    end

    def call_tool(:filesystem, "read_text_file", %{"path" => "/tmp/readme.md"}, opts) do
      assert opts[:timeout] == 1_000

      {:ok,
       %{
         status: :ok,
         data: %{
           "content" => [%{"type" => "text", "text" => "hello"}]
         }
       }}
    end

    def call_tool(:filesystem, "fail", %{}, opts) do
      assert opts[:timeout] == 1_000
      {:error, %{type: :transport, message: "transport failed"}}
    end
  end

  defmodule BadMCPClient do
    def list_tools(:filesystem, _opts), do: :bad_response
  end

  defmodule RaisingMCPClient do
    def list_tools(:filesystem, _opts), do: raise("mcp exploded")
  end

  defmodule PreferCallRanker do
    def rank(_query, _candidates), do: [%{provider: :mcp, id: "mcp.tool.call"}]
  end

  setup do
    register_endpoint!(:filesystem)

    :ok
  end

  test "MCP integration declares bridge actions" do
    spec = Jido.Connect.MCP.integration()

    assert spec.id == :mcp
    assert spec.package == :jido_connect_mcp
    assert spec.status == :experimental
    assert spec.metadata.bridge?
    assert [%{id: :endpoint_access}] = spec.policies
    assert {:endpoint, :api_key} in Enum.map(spec.auth_profiles, &{&1.id, &1.kind})

    assert {:ok,
            %{
              id: "mcp.tools.list",
              resource: :mcp_tool,
              verb: :list,
              policies: [:endpoint_access],
              mutation?: false,
              scope_resolver: Jido.Connect.MCP.ScopeResolver
            }} = Connect.action(spec, "mcp.tools.list")

    assert {:ok,
            %{
              id: "mcp.tool.call",
              mutation?: true,
              confirmation: :required_for_ai,
              scope_resolver: Jido.Connect.MCP.ScopeResolver
            }} = Connect.action(spec, "mcp.tool.call")
  end

  test "MCP catalog entry exposes bridge and runtime capabilities" do
    entry = Connect.Catalog.entry(Jido.Connect.MCP)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_mcp
    assert entry.status == :experimental
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :mcp_bridge)
  end

  test "MCP integration compiles generated Jido modules" do
    assert Application.get_env(:jido_connect_mcp, :jido_connect_providers) == [
             Jido.Connect.MCP
           ]

    assert Jido.Connect.MCP.jido_action_modules() == [
             Jido.Connect.MCP.Actions.ListTools,
             Jido.Connect.MCP.Actions.CallTool
           ]

    assert Jido.Connect.MCP.jido_sensor_modules() == []
    assert Jido.Connect.MCP.jido_plugin_module() == Jido.Connect.MCP.Plugin

    assert %Connect.Catalog.Manifest{
             id: :mcp,
             package: :jido_connect_mcp,
             generated_modules: %{
               actions: [
                 Jido.Connect.MCP.Actions.ListTools,
                 Jido.Connect.MCP.Actions.CallTool
               ],
               sensors: [],
               plugin: Jido.Connect.MCP.Plugin
             }
           } = Jido.Connect.MCP.jido_connect_manifest()

    assert {:module, Jido.Connect.MCP.Actions.ListTools} =
             Code.ensure_loaded(Jido.Connect.MCP.Actions.ListTools)

    assert {:module, Jido.Connect.MCP.Plugin} = Code.ensure_loaded(Jido.Connect.MCP.Plugin)
    assert function_exported?(Jido.Connect.MCP.Actions.ListTools, :run, 2)
    assert function_exported?(Jido.Connect.MCP.Plugin, :plugin_spec, 1)
  end

  test "generated list tools action delegates through Jido MCP" do
    {context, lease} = context_and_lease()

    assert {:ok, %{endpoint_id: "filesystem", tools: [tool]}} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               %{integration_context: context, credential_lease: lease}
             )

    assert tool.name == "read_text_file"
    assert tool.description == "Read a text file"
    assert tool.input_schema == %{"type" => "object"}
  end

  test "list tools supports clients without explicit timeout opts" do
    {context, lease} = context_and_lease()

    assert {:ok, %{tools: [tool]}} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem"},
               %{integration_context: context, credential_lease: lease}
             )

    assert tool.description == "Read a text file without a timeout"
  end

  test "generated call tool action delegates through Jido MCP" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              result: %{
                endpoint_id: "filesystem",
                tool_name: "read_text_file",
                content: [%{"text" => "hello"}],
                is_error?: false
              }
            }} =
             Jido.Connect.MCP.Actions.CallTool.run(
               %{
                 endpoint_id: "filesystem",
                 tool_name: "read_text_file",
                 arguments: %{"path" => "/tmp/readme.md"},
                 timeout: 1_000
               },
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "MCP client errors normalize to provider errors" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "mcp:tools:call",
          "mcp:endpoint:filesystem",
          "mcp:tool:fail"
        ]
      )

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :transport,
              message: "MCP request failed"
            }} =
             Jido.Connect.MCP.Actions.CallTool.run(
               %{
                 endpoint_id: "filesystem",
                 tool_name: "fail",
                 arguments: %{},
                 timeout: 1_000
               },
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "MCP invalid client responses normalize to provider errors" do
    {context, lease} = context_and_lease(mcp_client: BadMCPClient)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :invalid_response,
              details: %{response: "bad_response"}
            }} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "MCP client exceptions normalize to provider errors" do
    {context, lease} = context_and_lease(mcp_client: RaisingMCPClient)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :client_exception,
              details: %{message: "mcp exploded"}
            }} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "unknown MCP endpoint returns validation error after scope policy passes" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "mcp:tools:list",
          "mcp:endpoint:*"
        ]
      )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :unknown_mcp_endpoint,
              subject: "missing"
            }} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "missing"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "runtime registered MCP endpoints resolve through the bridge" do
    register_endpoint!(:runtime_registered)

    assert {:ok, :runtime_registered} =
             Jido.Connect.MCP.EndpointResolver.resolve("runtime_registered")
  end

  test "scope resolver rejects ungranted tools before handler execution" do
    {context, lease} = context_and_lease(scopes: ["mcp:tools:call", "mcp:endpoint:filesystem"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["mcp:tool:write_file"]
            }} =
             Jido.Connect.MCP.Actions.CallTool.run(
               %{
                 endpoint_id: "filesystem",
                 tool_name: "write_file",
                 arguments: %{},
                 timeout: 1_000
               },
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated plugin filters actions and reports availability" do
    spec = Jido.Connect.MCP.Plugin.plugin_spec(%{})

    assert spec.actions == [
             Jido.Connect.MCP.Actions.ListTools,
             Jido.Connect.MCP.Actions.CallTool
           ]

    filtered =
      Jido.Connect.MCP.Plugin.plugin_spec(%{
        allowed_actions: ["mcp.tools.list"]
      })

    assert filtered.actions == [Jido.Connect.MCP.Actions.ListTools]

    [available | _] =
      Jido.Connect.MCP.Plugin.tool_availability(%{
        connection: elem(context_and_lease(), 0).connection
      })

    assert available.state == :available

    [missing_scopes | _] =
      Jido.Connect.MCP.Plugin.tool_availability(%{
        connection: %{elem(context_and_lease(), 0).connection | scopes: []}
      })

    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["mcp:tools:list"]
  end

  test "catalog adapter exposes search, describe, and call tools through core catalog APIs" do
    assert Enum.map(Jido.Connect.MCP.CatalogAdapter.tools(), & &1.name) == [
             "jido_connect.catalog.search",
             "jido_connect.catalog.describe",
             "jido_connect.catalog.call"
           ]

    assert {:ok, %{results: [%{tool: %{id: "mcp.tools.list"}} | _]}} =
             Jido.Connect.MCP.CatalogAdapter.call(
               "jido_connect.catalog.search",
               %{query: "list MCP tools", limit: 1},
               modules: [Jido.Connect.MCP]
             )

    assert {:ok,
            %{
              descriptor: %{
                tool: %{id: "mcp.tools.list"},
                input: [%{name: :endpoint_id} | _],
                scopes: ["mcp:tools:list"],
                source: :mcp
              }
            }} =
             Jido.Connect.MCP.CatalogAdapter.call(
               "jido_connect.catalog.describe",
               %{tool_id: "mcp.tools.list"},
               modules: [Jido.Connect.MCP]
             )

    {context, lease} = context_and_lease()

    assert {:ok, %{result: %{endpoint_id: "filesystem", tools: [%{name: "read_text_file"}]}}} =
             Jido.Connect.MCP.CatalogAdapter.call(
               "jido_connect.catalog.call",
               %{tool_id: "mcp.tools.list", input: %{endpoint_id: "filesystem"}},
               modules: [Jido.Connect.MCP],
               runtime_opts: [
                 modules: [Jido.Connect.MCP],
                 context: context,
                 credential_lease: lease
               ]
             )

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_catalog_mcp_tool}} =
             Jido.Connect.MCP.CatalogAdapter.call("missing", %{}, modules: [Jido.Connect.MCP])
  end

  test "catalog adapter supports filters, provider-qualified refs, and safe errors" do
    assert {:ok, %{results: []}} =
             Jido.Connect.MCP.CatalogAdapter.search(
               %{
                 "query" => "mcp",
                 "limit" => 0,
                 "filters" => %{"type" => "action", "unknown" => "ignored"}
               },
               modules: [Jido.Connect.MCP]
             )

    assert {:ok, %{results: [%{tool: %{id: "mcp.tool.call", type: :action}}]}} =
             Jido.Connect.MCP.CatalogAdapter.search(
               %{"query" => "call", "filters" => %{"type" => "action"}},
               modules: [Jido.Connect.MCP]
             )

    assert {:ok, %{descriptor: %{tool: %{id: "mcp.tool.call"}}}} =
             Jido.Connect.MCP.CatalogAdapter.describe(
               %{"provider" => "mcp", "tool_id" => "mcp.tool.call"},
               modules: [Jido.Connect.MCP]
             )

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_tool}} =
             Jido.Connect.MCP.CatalogAdapter.describe(
               %{"tool_id" => "missing"},
               modules: [Jido.Connect.MCP]
             )

    assert {:error, %Connect.Error.AuthError{reason: :context_required}} =
             Jido.Connect.MCP.CatalogAdapter.call_catalog_tool(
               %{"tool_id" => "mcp.tools.list", "input" => %{"endpoint_id" => "filesystem"}},
               modules: [Jido.Connect.MCP]
             )
  end

  test "catalog adapter handles atom filters, invalid limits, and missing tool calls" do
    [search_tool, describe_tool, call_tool] = Jido.Connect.MCP.CatalogAdapter.tools()

    assert search_tool.annotations.readOnlyHint
    assert describe_tool.annotations.readOnlyHint
    refute call_tool.annotations.readOnlyHint

    assert {:ok, %{results: [%{tool: %{id: "mcp.tools.list"}} | _]}} =
             Jido.Connect.MCP.CatalogAdapter.search(
               %{
                 query: "tools",
                 limit: "not-an-integer",
                 filters: %{
                   "missing_filter_for_rescue" => true,
                   type: :action,
                   resource: :mcp_tool
                 }
               },
               modules: [Jido.Connect.MCP]
             )

    assert {:ok, %{descriptor: %{tool: %{id: "mcp.tools.list"}}}} =
             Jido.Connect.MCP.CatalogAdapter.describe(
               %{provider: :mcp, id: "mcp.tools.list", filters: %{type: :action}},
               modules: [Jido.Connect.MCP]
             )

    assert {:ok,
            %{results: [%{tool: %{id: "mcp.tool.call"}, metadata: %{ranker: %{rank: 1}}} | _]}} =
             Jido.Connect.MCP.CatalogAdapter.search(
               %{query: "mcp", filters: "invalid-filter-shape"},
               modules: [Jido.Connect.MCP],
               ranker: PreferCallRanker
             )

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_tool}} =
             Jido.Connect.MCP.CatalogAdapter.call_catalog_tool(
               %{provider: :mcp, tool_id: "missing", input: %{}},
               modules: [Jido.Connect.MCP],
               runtime_opts: []
             )
  end

  test "catalog adapter accepts map runtime opts for catalog calls" do
    {context, lease} = context_and_lease()

    assert {:ok, %{result: %{endpoint_id: "filesystem", tools: [%{name: "read_text_file"}]}}} =
             Jido.Connect.MCP.CatalogAdapter.call_catalog_tool(
               %{tool_id: "mcp.tools.list", input: %{endpoint_id: "filesystem"}},
               modules: [Jido.Connect.MCP],
               runtime_opts: %{
                 modules: [Jido.Connect.MCP],
                 context: context,
                 credential_lease: lease
               }
             )
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "mcp:tools:list",
        "mcp:tools:call",
        "mcp:endpoint:filesystem",
        "mcp:tool:read_text_file"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "mcp-filesystem",
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "tenant_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "mcp-filesystem",
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{mcp_client: Keyword.get(opts, :mcp_client, FakeMCPClient)}
      })

    {context, lease}
  end

  defp register_endpoint!(endpoint_id) do
    {:ok, endpoint} =
      Jido.MCP.Endpoint.new(endpoint_id, %{
        transport: {:stdio, [command: "echo"]},
        client_info: %{name: "jido-connect-mcp-test"}
      })

    case Jido.MCP.register_endpoint(endpoint) do
      {:ok, _endpoint} -> :ok
      {:error, {:endpoint_already_registered, ^endpoint_id}} -> :ok
    end
  end
end
