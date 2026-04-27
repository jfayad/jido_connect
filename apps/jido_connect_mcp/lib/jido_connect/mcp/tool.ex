defmodule Jido.Connect.MCP.Tool do
  @moduledoc "Normalized MCP tool metadata exposed by the bridge."

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              input_schema: Zoi.map() |> Zoi.default(%{}),
              annotations: Zoi.map() |> Zoi.default(%{}),
              raw: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)

  def from_mcp(%{} = tool) do
    new!(%{
      name: get(tool, "name"),
      description: get(tool, "description"),
      input_schema: get(tool, "inputSchema", %{}),
      annotations: get(tool, "annotations", %{}),
      raw: tool
    })
  end

  def to_map(%__MODULE__{} = tool) do
    %{
      name: tool.name,
      description: tool.description,
      input_schema: tool.input_schema,
      annotations: tool.annotations,
      raw: tool.raw
    }
  end

  defp get(map, key, default \\ nil), do: Jido.Connect.Data.get(map, key, default)
end
