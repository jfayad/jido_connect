defmodule Jido.Connect.Google.Contacts.Email do
  @moduledoc "Normalized Google Contacts email address metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              value: Zoi.string(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              formatted_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
