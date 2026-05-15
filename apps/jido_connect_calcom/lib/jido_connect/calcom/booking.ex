defmodule Jido.Connect.Calcom.Booking do
  @moduledoc "Normalized Cal.com booking."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              uid: Zoi.string(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              end: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              duration: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              location: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              event_type_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              cancellation_reason: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              rescheduling_reason: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
