defmodule Jido.Connect.Gmail.Label do
  @moduledoc "Normalized Gmail label metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              label_id: Zoi.string(),
              name: Zoi.string(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              message_list_visibility: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              label_list_visibility: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              messages_total: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              messages_unread: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              threads_total: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              threads_unread: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              color: Zoi.map() |> Zoi.default(%{}),
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
