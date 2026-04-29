defmodule Jido.Connect.Catalog.DiscoveryResult do
  @moduledoc "Catalog discovery result with entries plus diagnostics for unavailable connectors."

  alias Jido.Connect.Catalog.{Diagnostic, Entry}

  @schema Zoi.struct(
            __MODULE__,
            %{
              entries: Zoi.list(Entry.schema()) |> Zoi.default([]),
              diagnostics: Zoi.list(Diagnostic.schema()) |> Zoi.default([])
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
