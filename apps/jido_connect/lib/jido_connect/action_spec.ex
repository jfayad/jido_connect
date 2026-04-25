defmodule Jido.Connect.ActionSpec do
  @moduledoc "Provider action contract."

  alias Jido.Connect.Field

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              name: Zoi.atom(),
              label: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              auth_profile: Zoi.atom(),
              handler: Zoi.module(),
              input: Zoi.list(Field.schema()) |> Zoi.default([]),
              output: Zoi.list(Field.schema()) |> Zoi.default([]),
              input_schema: Zoi.any(),
              output_schema: Zoi.any(),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              mutation?: Zoi.boolean() |> Zoi.default(false),
              risk: Zoi.atom() |> Zoi.default(:read),
              confirmation: Zoi.atom() |> Zoi.default(:none),
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
