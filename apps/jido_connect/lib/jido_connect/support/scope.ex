defmodule Jido.Connect.Scope do
  @moduledoc "Helpers for provider scope parsing and encoding."

  @spec parse(nil | String.t() | [String.t()]) :: [String.t()]
  def parse(nil), do: []
  def parse(scopes) when is_list(scopes), do: scopes
  def parse(scopes) when is_binary(scopes), do: String.split(scopes, ~r/[\s,]+/, trim: true)

  @spec encode(String.t() | [String.t()], keyword()) :: String.t()
  def encode(scopes, opts \\ [])

  def encode(scopes, opts) when is_list(scopes),
    do: Enum.join(scopes, Keyword.get(opts, :separator, " "))

  def encode(scope, _opts) when is_binary(scope), do: scope
end
