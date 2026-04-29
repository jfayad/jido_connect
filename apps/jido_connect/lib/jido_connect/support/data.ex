defmodule Jido.Connect.Data do
  @moduledoc """
  Small data-shaping helpers shared by provider packages.
  """

  @doc "Gets a value from a map using string or atom variants of `key`."
  def get(map, key, default \\ nil)

  def get(map, key, default) when is_map(map) and is_binary(key) do
    cond do
      Map.has_key?(map, key) ->
        Map.fetch!(map, key)

      atom_key = existing_atom(key) ->
        Map.get(map, atom_key, default)

      true ->
        default
    end
  end

  def get(map, key, default) when is_map(map) and is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.fetch!(map, key)
      Map.has_key?(map, string_key) -> Map.fetch!(map, string_key)
      true -> default
    end
  end

  def get(_map, _key, default), do: default

  @doc "Fetches a value from a map using string or atom variants of `key`."
  def fetch!(map, key) do
    case get(map, key, :__jido_connect_missing__) do
      :__jido_connect_missing__ -> raise KeyError, key: key, term: map
      value -> value
    end
  end

  @doc "Returns a map without nil or blank-string values."
  def compact(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  @doc "Normalizes string-keyed maps to atom keys where atoms already exist."
  def atomize_existing_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        case existing_atom(key) do
          nil -> {key, value}
          atom -> {atom, value}
        end

      pair ->
        pair
    end)
  end

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
