defmodule Jido.Connect.Google.Pagination do
  @moduledoc "Helpers for Google page-token list APIs."

  alias Jido.Connect.Data

  @doc "Adds page-token options to a query map."
  @spec query(map(), keyword() | map()) :: map()
  def query(base \\ %{}, opts \\ %{}) when is_map(base) do
    opts = Map.new(opts)

    base
    |> maybe_put(:pageToken, Map.get(opts, :page_token) || Map.get(opts, "page_token"))
    |> maybe_put(:pageSize, Map.get(opts, :page_size) || Map.get(opts, "page_size"))
    |> maybe_put(:maxResults, Map.get(opts, :max_results) || Map.get(opts, "max_results"))
  end

  @doc "Extracts the next page token from a Google list response body."
  @spec next_page_token(map()) :: String.t() | nil
  def next_page_token(body) when is_map(body) do
    Data.get(body, "nextPageToken")
  end

  def next_page_token(_body), do: nil

  @doc "Builds checkpoint metadata from a list response body."
  @spec checkpoint(map(), map()) :: map()
  def checkpoint(body, extra \\ %{}) when is_map(body) and is_map(extra) do
    %{
      next_page_token: next_page_token(body)
    }
    |> Map.merge(extra)
    |> Data.compact()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
