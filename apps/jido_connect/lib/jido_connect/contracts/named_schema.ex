defmodule Jido.Connect.NamedSchema do
  @moduledoc "Reusable named schema declared by an integration."

  alias Jido.Connect.Field

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              fields: Zoi.list(Field.schema()) |> Zoi.default([]),
              zoi_schema: Zoi.any(),
              metadata: Zoi.map() |> Zoi.default(%{})
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
