defmodule Jido.Connect.Google.Calendar.FreeBusy do
  @moduledoc "Normalized Google Calendar free/busy response."

  @schema Zoi.struct(
            __MODULE__,
            %{
              time_min: Zoi.string(),
              time_max: Zoi.string(),
              calendars: Zoi.map() |> Zoi.default(%{}),
              groups: Zoi.map() |> Zoi.default(%{}),
              busy: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
