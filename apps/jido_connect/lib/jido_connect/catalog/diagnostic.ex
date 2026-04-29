defmodule Jido.Connect.Catalog.Diagnostic do
  @moduledoc "Diagnostic emitted when catalog discovery cannot load or build a connector entry."

  @schema Zoi.struct(
            __MODULE__,
            %{
              module: Zoi.module(),
              reason: Zoi.atom(),
              message: Zoi.string(),
              details: Zoi.map() |> Zoi.default(%{})
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
