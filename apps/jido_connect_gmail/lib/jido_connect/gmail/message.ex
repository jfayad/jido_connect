defmodule Jido.Connect.Gmail.Message do
  @moduledoc """
  Normalized Gmail message metadata.

  This struct intentionally stores snippets, headers, labels, and payload
  summaries only. It does not expose raw RFC822 bodies, MIME part body data, or
  the Gmail `raw` field.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              message_id: Zoi.string(),
              thread_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              label_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              snippet: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              history_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              internal_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size_estimate: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              headers: Zoi.list(Zoi.map()) |> Zoi.default([]),
              payload_summary: Zoi.map() |> Zoi.default(%{}),
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
