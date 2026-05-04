defmodule Jido.Connect.MCP.CatalogAdapter do
  @moduledoc """
  Thin MCP-facing adapter for the Jido Connect catalog.

  This module is intentionally not a `Jido.Connect` provider action. Catalog
  execution must run with the target provider's runtime context and credential
  lease, not with the MCP endpoint bridge connection.
  """

  alias Jido.Connect.{Catalog, Data, Error}

  @tool_search "jido_connect.catalog.search"
  @tool_describe "jido_connect.catalog.describe"
  @tool_call "jido_connect.catalog.call"

  @doc "Returns MCP-style tool definitions for catalog search, describe, and call."
  def tools do
    [
      %{
        name: @tool_search,
        description: "Search Jido Connect catalog tools.",
        input_schema: %{
          type: "object",
          properties: %{
            query: %{type: "string"},
            limit: %{type: "integer"},
            filters: %{type: "object"}
          }
        },
        annotations: %{readOnlyHint: true}
      },
      %{
        name: @tool_describe,
        description: "Describe one Jido Connect catalog tool.",
        input_schema: %{
          type: "object",
          required: ["tool_id"],
          properties: %{
            provider: %{type: "string"},
            tool_id: %{type: "string"},
            filters: %{type: "object"}
          }
        },
        annotations: %{readOnlyHint: true}
      },
      %{
        name: @tool_call,
        description: "Call one Jido Connect action tool through the catalog runtime boundary.",
        input_schema: %{
          type: "object",
          required: ["tool_id", "input"],
          properties: %{
            provider: %{type: "string"},
            tool_id: %{type: "string"},
            input: %{type: "object"},
            filters: %{type: "object"}
          }
        },
        annotations: %{readOnlyHint: false}
      }
    ]
  end

  @doc "Dispatches one catalog MCP adapter tool by name."
  def call(tool_name, input, opts \\ [])

  def call(@tool_search, input, opts), do: search(input, opts)
  def call(@tool_describe, input, opts), do: describe(input, opts)
  def call(@tool_call, input, opts), do: call_catalog_tool(input, opts)

  def call(tool_name, _input, _opts) do
    {:error,
     Error.validation("Unknown Jido Connect catalog MCP tool",
       reason: :unknown_catalog_mcp_tool,
       subject: tool_name
     )}
  end

  def search(input, opts \\ []) when is_map(input) do
    query = Data.get(input, "query", "")
    limit = Data.get(input, "limit")

    results =
      query
      |> Catalog.search_tools(catalog_opts(input, opts))
      |> limit_results(limit)
      |> Enum.map(&Catalog.to_map/1)

    {:ok, %{results: results}}
  end

  def describe(input, opts \\ []) when is_map(input) do
    with {:ok, descriptor} <- Catalog.describe_tool(tool_ref(input), catalog_opts(input, opts)) do
      {:ok, %{descriptor: Catalog.to_map(descriptor)}}
    end
  end

  def call_catalog_tool(input, opts \\ []) when is_map(input) do
    runtime_opts = Keyword.get(opts, :runtime_opts, opts)

    with {:ok, result} <-
           Catalog.call_tool(
             tool_ref(input),
             Data.get(input, "input", %{}),
             Keyword.merge(catalog_opts(input, opts), normalize_opts(runtime_opts))
           ) do
      {:ok, %{result: result}}
    end
  end

  defp tool_ref(input) do
    provider = Data.get(input, "provider")
    tool_id = Data.get(input, "tool_id") || Data.get(input, "id")

    if provider do
      {provider, tool_id}
    else
      tool_id
    end
  end

  defp catalog_opts(input, opts) do
    opts
    |> Keyword.take([
      :modules,
      :ranker,
      :type,
      :resource,
      :verb,
      :risk,
      :confirmation,
      :auth_kind
    ])
    |> Keyword.merge(filters(input))
  end

  defp filters(input) do
    case Data.get(input, "filters", %{}) do
      filters when is_map(filters) or is_list(filters) ->
        Enum.map(filters, fn {key, value} -> {normalize_filter_key(key), value} end)

      _other ->
        []
    end
  end

  defp normalize_filter_key(key) when is_atom(key), do: key

  defp normalize_filter_key(key) when is_binary(key) do
    case key do
      "type" -> :type
      "provider" -> :provider
      "resource" -> :resource
      "verb" -> :verb
      "risk" -> :risk
      "confirmation" -> :confirmation
      "auth_kind" -> :auth_kind
      "auth_profile" -> :auth_profile
      "scope" -> :scope
      "package" -> :package
      "category" -> :category
      "tag" -> :tag
      other -> existing_or_unknown(other)
    end
  end

  defp existing_or_unknown(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> :unknown_filter
  end

  defp limit_results(results, limit) when is_integer(limit) and limit >= 0,
    do: Enum.take(results, limit)

  defp limit_results(results, _limit), do: results

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(_opts), do: []
end
