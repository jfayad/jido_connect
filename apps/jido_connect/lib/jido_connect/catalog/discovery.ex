defmodule Jido.Connect.Catalog.Discovery do
  @moduledoc false

  alias Jido.Connect.Callback
  alias Jido.Connect.Catalog.{Builder, Diagnostic, DiscoveryResult, Filter, Search}

  @spec configured_modules() :: [module()]
  def configured_modules do
    :jido_connect
    |> Application.get_env(:catalog_modules, [])
    |> normalize_modules()
  end

  @spec discover(keyword()) :: [Jido.Connect.Catalog.Entry.t()]
  def discover(opts \\ []) do
    opts
    |> discover_with_diagnostics()
    |> Map.fetch!(:entries)
  end

  @spec discover_with_diagnostics(keyword()) :: DiscoveryResult.t()
  def discover_with_diagnostics(opts \\ []) do
    modules =
      opts
      |> Keyword.get(:modules, configured_modules())
      |> normalize_modules()

    {entries, diagnostics} =
      modules
      |> Enum.map(&entry_result/1)
      |> split_results()

    entries =
      entries
      |> Filter.entries(opts)
      |> Search.entries(Keyword.get(opts, :query, Keyword.get(opts, :q)))

    DiscoveryResult.new!(%{entries: entries, diagnostics: diagnostics})
  end

  defp split_results(results) do
    Enum.reduce(results, {[], []}, fn
      {:entry, entry}, {entries, diagnostics} ->
        {[entry | entries], diagnostics}

      {:diagnostic, diagnostic}, {entries, diagnostics} ->
        {entries, [diagnostic | diagnostics]}
    end)
    |> then(fn {entries, diagnostics} -> {Enum.reverse(entries), Enum.reverse(diagnostics)} end)
  end

  defp entry_result(module) do
    with {:module, ^module} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :integration, 0),
         {:ok, entry} <-
           Callback.run(fn -> Builder.entry(module) end,
             phase: :catalog_discovery,
             details: %{module: module}
           ) do
      {:entry, entry}
    else
      {:error, %_{} = error} ->
        {:diagnostic,
         diagnostic(module, :entry_failed, "Catalog entry could not be built", %{
           error: Jido.Connect.Error.to_map(error)
         })}

      {:error, reason} ->
        {:diagnostic,
         diagnostic(module, :module_not_loaded, "Catalog module could not be loaded", %{
           reason: reason
         })}

      false ->
        {:diagnostic,
         diagnostic(
           module,
           :missing_integration_callback,
           "Catalog module does not export integration/0"
         )}

      _other ->
        {:diagnostic, diagnostic(module, :entry_failed, "Catalog entry could not be built")}
    end
  end

  defp diagnostic(module, reason, message, details \\ %{}) do
    Diagnostic.new!(%{
      module: module,
      reason: reason,
      message: message,
      details: details
    })
  end

  defp normalize_modules(modules) do
    modules
    |> List.wrap()
    |> Enum.map(&normalize_module/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_module(module) when is_atom(module), do: module

  defp normalize_module("Elixir." <> _rest = module) do
    module
    |> String.replace_prefix("Elixir.", "")
    |> normalize_module()
  end

  defp normalize_module(module) when is_binary(module) do
    module
    |> String.split(".", trim: true)
    |> Module.concat()
  rescue
    _error -> nil
  end
end
