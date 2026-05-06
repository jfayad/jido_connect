defmodule Jido.Connect.Gmail.Thread do
  @moduledoc "Normalized Gmail thread metadata with sanitized message summaries."

  @schema Zoi.struct(
            __MODULE__,
            %{
              thread_id: Zoi.string(),
              history_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              snippet: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              messages: Zoi.list(Jido.Connect.Gmail.Message.schema()) |> Zoi.default([]),
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
