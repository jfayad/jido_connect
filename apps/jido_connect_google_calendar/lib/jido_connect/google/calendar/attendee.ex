defmodule Jido.Connect.Google.Calendar.Attendee do
  @moduledoc "Normalized Google Calendar event attendee."

  @schema Zoi.struct(
            __MODULE__,
            %{
              email: Zoi.string(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              response_status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              comment: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              additional_guests: Zoi.integer() |> Zoi.default(0),
              optional?: Zoi.boolean() |> Zoi.default(false),
              organizer?: Zoi.boolean() |> Zoi.default(false),
              resource?: Zoi.boolean() |> Zoi.default(false),
              self?: Zoi.boolean() |> Zoi.default(false),
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
