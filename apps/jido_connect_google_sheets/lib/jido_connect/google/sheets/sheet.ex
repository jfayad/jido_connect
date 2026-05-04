defmodule Jido.Connect.Google.Sheets.Sheet do
  @moduledoc "Normalized Google Sheets sheet/tab metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              sheet_id: Zoi.integer(),
              title: Zoi.string(),
              index: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              row_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              column_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              hidden?: Zoi.boolean() |> Zoi.default(false),
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
