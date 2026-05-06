defmodule Jido.Connect.Google.Contacts.Phone do
  @moduledoc "Normalized Google Contacts phone number metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              value: Zoi.string(),
              canonical_form: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              formatted_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
