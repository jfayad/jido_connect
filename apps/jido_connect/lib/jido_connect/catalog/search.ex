defmodule Jido.Connect.Catalog.Search do
  @moduledoc false

  alias Jido.Connect.Catalog.{Entry, Tool, ToolEntry}

  @spec entries([Entry.t()], String.t() | nil) :: [Entry.t()]
  def entries(entries, query) when query in [nil, ""], do: entries

  def entries(entries, query) when is_binary(query) do
    normalized_query = String.downcase(query)

    Enum.filter(entries, fn entry ->
      entry
      |> searchable_text()
      |> String.contains?(normalized_query)
    end)
  end

  @spec tools([ToolEntry.t()], String.t() | nil) :: [ToolEntry.t()]
  def tools(tools, query) when query in [nil, ""], do: tools

  def tools(tools, query) when is_binary(query) do
    normalized_query = String.downcase(query)

    Enum.filter(tools, fn tool ->
      tool
      |> tool_entry_search_text()
      |> String.contains?(normalized_query)
    end)
  end

  defp searchable_text(%Entry{} = entry) do
    [
      entry.id,
      entry.name,
      entry.description,
      entry.category,
      entry.package,
      entry.status,
      entry.tags,
      entry.visibility,
      inspect(entry.module),
      Enum.map(entry.docs, & &1),
      Enum.map(entry.capabilities, &[&1.kind, &1.feature, &1.label]),
      Enum.map(entry.policies, &[&1.id, &1.label, &1.description, &1.decision]),
      Enum.map(entry.schemas, &[&1.id, &1.label, &1.description]),
      Enum.map(entry.auth_profiles, &[&1.id, &1.kind, &1.label, &1.scopes, &1.default_scopes]),
      Enum.map(entry.actions, &tool_search_text/1),
      Enum.map(entry.triggers, &tool_search_text/1)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
  end

  defp tool_search_text(%Tool{} = tool) do
    [
      tool.type,
      tool.id,
      tool.name,
      tool.label,
      tool.description,
      inspect(tool.module),
      tool.resource,
      tool.verb,
      tool.data_classification,
      tool.auth_profile,
      tool.auth_profiles,
      tool.policies,
      tool.scopes,
      tool.risk,
      tool.confirmation,
      tool.trigger_kind
    ]
  end

  defp tool_entry_search_text(%ToolEntry{} = tool) do
    [
      tool.provider,
      tool.provider_name,
      tool.category,
      tool.package,
      tool.type,
      tool.id,
      tool.name,
      tool.label,
      tool.description,
      inspect(tool.module),
      tool.resource,
      tool.verb,
      tool.data_classification,
      tool.auth_profile,
      tool.auth_profiles,
      tool.auth_kinds,
      tool.policies,
      tool.scopes,
      tool.risk,
      tool.confirmation,
      tool.trigger_kind
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
  end
end
