defmodule Jido.Connect.Catalog.Ranker do
  @moduledoc false

  alias Jido.Connect.{Callback, Error, Sanitizer}
  alias Jido.Connect.Catalog.{Serializer, ToolLookup, ToolSearchResult}

  @spec apply([ToolSearchResult.t()], String.t() | nil, term()) :: [ToolSearchResult.t()]
  def apply(results, _query, ranker) when ranker in [nil, false], do: results

  def apply(results, query, ranker) do
    candidates = Enum.map(results, &candidate_payload/1)

    case call_ranker(ranker, query, candidates) do
      {:ok, refs} ->
        reorder_results(results, refs)

      {:error, error} ->
        annotate_fallback(results, error)
    end
  end

  defp call_ranker(ranker, query, candidates) do
    sanitized_candidates = Sanitizer.sanitize(candidates, :transport)

    with {:ok, result} <-
           Callback.run(fn -> invoke_ranker(ranker, query, sanitized_candidates) end,
             phase: :catalog_ranker,
             details: ranker_details(ranker)
           ) do
      normalize_ranker_result(result)
    end
  end

  defp invoke_ranker(fun, query, candidates) when is_function(fun, 2), do: fun.(query, candidates)

  defp invoke_ranker(module, query, candidates) when is_atom(module) do
    if function_exported?(module, :rank, 2) do
      Kernel.apply(module, :rank, [query, candidates])
    else
      raise ArgumentError, "catalog ranker module must export rank/2"
    end
  end

  defp invoke_ranker({module, function}, query, candidates)
       when is_atom(module) and is_atom(function) do
    Kernel.apply(module, function, [query, candidates])
  end

  defp invoke_ranker({module, function, extra_args}, query, candidates)
       when is_atom(module) and is_atom(function) and is_list(extra_args) do
    Kernel.apply(module, function, [query, candidates | extra_args])
  end

  defp invoke_ranker(other, _query, _candidates) do
    raise ArgumentError, "invalid catalog ranker: #{inspect(other)}"
  end

  defp normalize_ranker_result({:ok, refs}) when is_list(refs), do: {:ok, refs}
  defp normalize_ranker_result(refs) when is_list(refs), do: {:ok, refs}

  defp normalize_ranker_result(other) do
    {:error,
     Error.execution("Catalog ranker returned an invalid result",
       phase: :catalog_ranker,
       details: %{returned: Sanitizer.sanitize(other, :transport)}
     )}
  end

  defp reorder_results(results, refs) do
    result_by_key = Map.new(results, &{ToolLookup.key(&1.tool), &1})
    tools = Enum.map(results, & &1.tool)

    {ranked, seen} =
      refs
      |> Enum.map(&resolve_ref(&1, tools))
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce({[], MapSet.new()}, fn {key, reason}, {acc, seen} ->
        cond do
          MapSet.member?(seen, key) ->
            {acc, seen}

          result = Map.get(result_by_key, key) ->
            {[with_ranker_metadata(result, length(acc) + 1, reason) | acc], MapSet.put(seen, key)}

          true ->
            {acc, seen}
        end
      end)

    remaining =
      Enum.reject(results, fn result ->
        MapSet.member?(seen, ToolLookup.key(result.tool))
      end)

    Enum.reverse(ranked) ++ remaining
  end

  defp resolve_ref(ref, tools) do
    case ToolLookup.lookup(tools, ranker_tool_ref(ref)) do
      {:ok, tool} -> {ToolLookup.key(tool), ranker_reason(ref)}
      {:error, _error} -> nil
    end
  end

  defp ranker_tool_ref({provider, id}), do: {provider, id}

  defp ranker_tool_ref(%{} = ref) do
    provider = Map.get(ref, :provider) || Map.get(ref, "provider")

    id =
      Map.get(ref, :id) || Map.get(ref, "id") || Map.get(ref, :tool_id) || Map.get(ref, "tool_id")

    if provider && id do
      {provider, id}
    else
      id
    end
  end

  defp ranker_tool_ref(ref), do: ref

  defp ranker_reason(%{} = ref), do: Map.get(ref, :reason) || Map.get(ref, "reason")
  defp ranker_reason(_ref), do: nil

  defp with_ranker_metadata(%ToolSearchResult{} = result, rank, nil) do
    update_ranker_metadata(result, %{rank: rank})
  end

  defp with_ranker_metadata(%ToolSearchResult{} = result, rank, reason) do
    update_ranker_metadata(result, %{rank: rank, reason: reason})
  end

  defp annotate_fallback(results, error) do
    Enum.map(results, fn result ->
      update_ranker_metadata(result, %{status: :fallback, error: Error.to_map(error)})
    end)
  end

  defp update_ranker_metadata(%ToolSearchResult{} = result, ranker_metadata) do
    %{
      result
      | metadata:
          Map.update(result.metadata, :ranker, ranker_metadata, &Map.merge(&1, ranker_metadata))
    }
  end

  defp candidate_payload(%ToolSearchResult{} = result) do
    %{
      tool: Serializer.to_map(result.tool),
      score: result.score,
      matched_fields: result.matched_fields
    }
  end

  defp ranker_details(fun) when is_function(fun), do: %{ranker: :function}
  defp ranker_details(module) when is_atom(module), do: %{ranker: module, function: :rank}

  defp ranker_details({module, function}) when is_atom(module) and is_atom(function),
    do: %{ranker: module, function: function}

  defp ranker_details({module, function, extra_args}) when is_atom(module) and is_atom(function),
    do: %{ranker: module, function: function, arity: 2 + length(extra_args)}

  defp ranker_details(other), do: %{ranker: inspect(other)}
end
