defmodule Jido.Connect.Google.Sheets.ValueRange do
  @moduledoc "Normalized Google Sheets value range."

  @schema Zoi.struct(
            __MODULE__,
            %{
              spreadsheet_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              range: Zoi.string(),
              major_dimension: Zoi.enum(["ROWS", "COLUMNS"]) |> Zoi.default("ROWS"),
              values: Zoi.list(Zoi.list(Zoi.any())) |> Zoi.default([]),
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
