defmodule Jido.Connect.Google.Calendar.Event do
  @moduledoc "Normalized Google Calendar event metadata."

  alias Jido.Connect.Google.Calendar.Attendee

  @schema Zoi.struct(
            __MODULE__,
            %{
              event_id: Zoi.string(),
              calendar_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              i_cal_uid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              summary: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              html_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              creator: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              organizer: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              start: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              end: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_time_zone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              end_time_zone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              all_day?: Zoi.boolean() |> Zoi.default(false),
              recurrence: Zoi.list(Zoi.string()) |> Zoi.default([]),
              recurring_event_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              original_start: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              attendees: Zoi.list(Attendee.schema()) |> Zoi.default([]),
              attendees_omitted?: Zoi.boolean() |> Zoi.default(false),
              hangout_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              conference_data: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              reminders: Zoi.map() |> Zoi.default(%{}),
              attachments: Zoi.list(Zoi.map()) |> Zoi.default([]),
              extended_properties: Zoi.map() |> Zoi.default(%{}),
              transparency: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              visibility: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              event_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              sequence: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
