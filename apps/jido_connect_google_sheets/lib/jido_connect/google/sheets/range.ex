defmodule Jido.Connect.Google.Sheets.Range do
  @moduledoc "Normalized Google Sheets A1 range reference."

  @schema Zoi.struct(
            __MODULE__,
            %{
              spreadsheet_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              sheet: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              a1: Zoi.string(),
              start_row: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              end_row: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              start_column: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              end_column: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
