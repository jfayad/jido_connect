defmodule Jido.Connect.Catalog.ToolLookup do
  @moduledoc false

  alias Jido.Connect.Catalog.ToolEntry
  alias Jido.Connect.Error

  @spec lookup([ToolEntry.t()], term()) :: {:ok, ToolEntry.t()} | {:error, Error.error()}
  def lookup(tools, %ToolEntry{} = tool), do: lookup(tools, {tool.provider, tool.id})

  def lookup(tools, {provider, tool_id}) do
    provider = provider_key(provider)
    tool_id = tool_id_key(tool_id)

    tools
    |> Enum.filter(&(provider_key(&1.provider) == provider and &1.id == tool_id))
    |> normalize_matches({provider, tool_id})
  end

  def lookup(tools, tool_ref) when is_binary(tool_ref) or is_atom(tool_ref) do
    tool_ref = tool_id_key(tool_ref)

    case exact_matches(tools, tool_ref) do
      [] -> provider_prefixed_matches(tools, tool_ref)
      matches -> matches
    end
    |> normalize_matches(tool_ref)
  end

  def lookup(_tools, tool_ref) do
    {:error,
     Error.validation("Invalid catalog tool reference",
       reason: :invalid_tool_ref,
       subject: tool_ref
     )}
  end

  defp exact_matches(tools, tool_ref), do: Enum.filter(tools, &(&1.id == tool_ref))

  defp provider_prefixed_matches(tools, tool_ref) do
    case String.split(tool_ref, ".", parts: 2) do
      [provider, id] ->
        Enum.filter(tools, &(provider_key(&1.provider) == provider and &1.id == id))

      _other ->
        []
    end
  end

  defp normalize_matches([tool], _tool_ref), do: {:ok, tool}

  defp normalize_matches([], tool_ref) do
    {:error,
     Error.validation("Unknown catalog tool",
       reason: :unknown_tool,
       subject: tool_ref
     )}
  end

  defp normalize_matches(matches, tool_ref) do
    {:error,
     Error.validation("Catalog tool reference is ambiguous",
       reason: :ambiguous_tool,
       subject: tool_ref,
       details: %{matches: Enum.map(matches, &%{provider: &1.provider, id: &1.id})}
     )}
  end

  def key(%ToolEntry{} = tool), do: {provider_key(tool.provider), tool.id}
  def provider_key(provider), do: provider |> to_string() |> String.trim()
  def tool_id_key(tool_id), do: tool_id |> to_string() |> String.trim()
end
