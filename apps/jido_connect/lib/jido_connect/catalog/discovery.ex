defmodule Jido.Connect.Catalog.Discovery do
  @moduledoc false

  alias Jido.Connect.Callback
  alias Jido.Connect.Catalog.{Builder, Filter, Search}

  @spec configured_modules() :: [module()]
  def configured_modules do
    :jido_connect
    |> Application.get_env(:catalog_modules, [])
    |> normalize_modules()
  end

  @spec discover(keyword()) :: [Jido.Connect.Catalog.Entry.t()]
  def discover(opts \\ []) do
    modules =
      opts
      |> Keyword.get(:modules, configured_modules())
      |> normalize_modules()

    modules
    |> Enum.flat_map(&safe_entry/1)
    |> Filter.entries(opts)
    |> Search.entries(Keyword.get(opts, :query, Keyword.get(opts, :q)))
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

  defp safe_entry(module) do
    with {:module, ^module} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :integration, 0),
         {:ok, entry} <-
           Callback.run(fn -> Builder.entry(module) end,
             phase: :catalog_discovery,
             details: %{module: module}
           ) do
      [entry]
    else
      _other -> []
    end
  end
end
