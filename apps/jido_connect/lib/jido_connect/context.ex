defmodule Jido.Connect.Context do
  @moduledoc "Host-provided tenant, actor, and connection selection context."

  @schema Zoi.struct(
            __MODULE__,
            %{
              tenant_id: Zoi.string(),
              actor: Zoi.map(),
              connection: Zoi.any() |> Zoi.optional(),
              claims: Zoi.map() |> Zoi.default(%{}),
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
