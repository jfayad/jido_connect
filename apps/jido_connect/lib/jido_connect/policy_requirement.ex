defmodule Jido.Connect.PolicyRequirement do
  @moduledoc "Declarative host policy requirement referenced by actions and triggers."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              subject: Zoi.any() |> Zoi.optional(),
              owner: Zoi.any() |> Zoi.optional(),
              decision: Zoi.atom() |> Zoi.default(:allow_operation),
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
