defmodule Jido.Connect.Catalog.Actions.SearchTools do
  @moduledoc "Search installed Jido Connect catalog tools."

  use Jido.Action,
    name: "connect_catalog_search",
    description: "Search Jido Connect catalog tools",
    category: "catalog",
    tags: ["jido_connect", "catalog", "search"],
    schema: %{
      "type" => "object",
      "properties" => %{
        "query" => %{"type" => "string"},
        "filters" => %{"type" => "object"},
        "limit" => %{"type" => "integer", "minimum" => 0},
        "pack" => %{}
      }
    },
    output_schema: %{
      "type" => "object",
      "properties" => %{"results" => %{"type" => "array"}}
    }

  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Input

  @impl true
  def run(params, context) do
    with {:ok, query, opts, limit} <- Input.search_params(params, context),
         results when is_list(results) <- Catalog.search_tools(query, opts) do
      {:ok, %{results: results |> limit_results(limit) |> Enum.map(&Catalog.to_map/1)}}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp limit_results(results, limit) when is_integer(limit), do: Enum.take(results, limit)
  defp limit_results(results, _limit), do: results
end
