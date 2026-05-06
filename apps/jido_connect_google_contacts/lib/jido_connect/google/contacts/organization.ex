defmodule Jido.Connect.Google.Contacts.Organization do
  @moduledoc "Normalized Google Contacts organization metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              department: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              symbol: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              domain: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              formatted_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_date: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              end_date: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              current?: Zoi.boolean() |> Zoi.default(false),
              primary?: Zoi.boolean() |> Zoi.default(false),
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
