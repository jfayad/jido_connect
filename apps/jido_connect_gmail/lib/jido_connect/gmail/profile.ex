defmodule Jido.Connect.Gmail.Profile do
  @moduledoc "Normalized Gmail mailbox profile metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              email_address: Zoi.string(),
              messages_total: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              threads_total: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              history_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
