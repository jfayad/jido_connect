defmodule Jido.Connect.Google.Sheets.Spreadsheet do
  @moduledoc "Normalized Google Sheets spreadsheet metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              spreadsheet_id: Zoi.string(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              locale: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              time_zone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              spreadsheet_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              sheets: Zoi.list(Jido.Connect.Google.Sheets.Sheet.schema()) |> Zoi.default([]),
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
