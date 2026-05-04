defmodule Jido.Connect.Google.Sheets.UpdateResult do
  @moduledoc "Normalized Google Sheets value update result."

  @schema Zoi.struct(
            __MODULE__,
            %{
              spreadsheet_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_range: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_rows: Zoi.integer() |> Zoi.default(0),
              updated_columns: Zoi.integer() |> Zoi.default(0),
              updated_cells: Zoi.integer() |> Zoi.default(0),
              table_range: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              cleared_range: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
