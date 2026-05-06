defmodule Jido.Connect.Gmail.Draft do
  @moduledoc "Normalized Gmail draft metadata with sanitized message summaries."

  @schema Zoi.struct(
            __MODULE__,
            %{
              draft_id: Zoi.string(),
              message: Jido.Connect.Gmail.Message.schema() |> Zoi.nullish() |> Zoi.optional(),
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
