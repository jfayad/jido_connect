defmodule Jido.Connect.Calcom.Webhook do
  @moduledoc "Normalized Cal.com webhook."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              subscriber_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              active: Zoi.boolean() |> Zoi.default(false),
              triggers: Zoi.list(Zoi.string()) |> Zoi.default([]),
              payload_template: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
