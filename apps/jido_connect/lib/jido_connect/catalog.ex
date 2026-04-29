defmodule Jido.Connect.Catalog do
  @moduledoc """
  Host-facing connector catalog metadata derived from integration specs.

  This gives demo apps and host UIs a stable, storage-free way to render
  available providers, auth modes, generated tools, and maturity metadata.
  """

  alias Jido.Connect.Catalog.{
    Builder,
    Discovery,
    DiscoveryResult,
    Entry,
    Filter,
    Manifest,
    Search,
    Serializer,
    ToolEntry
  }

  @spec entry(module(), keyword()) :: Entry.t()
  defdelegate entry(integration_module, opts \\ []), to: Builder

  @spec manifest(module(), keyword()) :: Manifest.t()
  defdelegate manifest(integration_module, opts \\ []), to: Builder

  @spec entries([module()], keyword()) :: [Entry.t()]
  def entries(integration_modules, opts \\ []) when is_list(integration_modules) do
    Enum.map(integration_modules, &entry(&1, opts))
  end

  @spec configured_modules() :: [module()]
  defdelegate configured_modules, to: Discovery

  @spec registered_modules() :: [module()]
  defdelegate registered_modules, to: Discovery

  @spec discover(keyword()) :: [Entry.t()]
  defdelegate discover(opts \\ []), to: Discovery

  @spec discover_with_diagnostics(keyword()) :: DiscoveryResult.t()
  defdelegate discover_with_diagnostics(opts \\ []), to: Discovery

  @spec search([Entry.t()], String.t() | nil) :: [Entry.t()]
  defdelegate search(entries, query), to: Search, as: :entries

  @spec filter([Entry.t()], keyword()) :: [Entry.t()]
  defdelegate filter(entries, opts), to: Filter, as: :entries

  @doc "Returns a flattened catalog of actions and triggers across discovered providers."
  @spec tools(keyword()) :: [ToolEntry.t()]
  def tools(opts \\ []) do
    provider_opts = Keyword.drop(opts, [:query, :q, :type, :risk, :confirmation])

    provider_opts
    |> discover()
    |> Enum.flat_map(&Builder.tool_entries/1)
    |> Filter.tool_entries(opts)
    |> Search.tools(Keyword.get(opts, :query, Keyword.get(opts, :q)))
  end

  @spec to_map(Entry.t() | Manifest.t() | ToolEntry.t()) :: map()
  defdelegate to_map(entry_or_tool), to: Serializer
end
