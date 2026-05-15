defmodule Jido.Connect.Calcom.EventType do
  @moduledoc "Normalized Cal.com event type."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer(),
              slug: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              length_in_minutes: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              hidden: Zoi.boolean() |> Zoi.default(false),
              is_instant_event: Zoi.boolean() |> Zoi.default(false),
              owner_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              booking_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              seats_per_time_slot: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              team_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
