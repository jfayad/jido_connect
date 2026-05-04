defmodule Jido.Connect.Catalog.ToolDescriptor do
  @moduledoc "Schema-rich catalog description for one action or trigger tool."

  alias Jido.Connect.{Field, PolicyRequirement}
  alias Jido.Connect.Catalog.{AuthProfileSummary, ToolEntry}

  @schema Zoi.struct(
            __MODULE__,
            %{
              tool: ToolEntry.schema(),
              provider: Zoi.map(),
              input: Zoi.list(Field.schema()) |> Zoi.default([]),
              output: Zoi.list(Field.schema()) |> Zoi.default([]),
              config: Zoi.list(Field.schema()) |> Zoi.default([]),
              signal: Zoi.list(Field.schema()) |> Zoi.default([]),
              auth: Zoi.list(AuthProfileSummary.schema()) |> Zoi.default([]),
              policies: Zoi.list(PolicyRequirement.schema()) |> Zoi.default([]),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              risk: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              confirmation: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              source: Zoi.atom() |> Zoi.default(:curated),
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
