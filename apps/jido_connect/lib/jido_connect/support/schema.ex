defmodule Jido.Connect.Schema do
  @moduledoc false

  alias Jido.Connect.{Error, Field}

  @doc false
  def zoi_schema_from_fields(fields) when is_list(fields) do
    fields
    |> Enum.map(fn %Field{} = field ->
      {field.name, zoi_field_schema(field)}
    end)
    |> Map.new()
    |> Zoi.object(coerce: true)
  end

  defp zoi_field_schema(%Field{} = field) do
    field.type
    |> zoi_type()
    |> maybe_enum(field.enum)
    |> maybe_default(field)
    |> maybe_optional(field)
  end

  defp zoi_type(:string), do: Zoi.string()
  defp zoi_type(:integer), do: Zoi.integer()
  defp zoi_type(:boolean), do: Zoi.boolean()
  defp zoi_type(:map), do: Zoi.map()
  defp zoi_type({:array, type}), do: Zoi.list(zoi_type(type))

  defp zoi_type(type) do
    raise Error.validation("Unsupported integration field type",
            reason: :unsupported_field_type,
            subject: type
          )
  end

  defp maybe_enum(schema, nil), do: schema
  defp maybe_enum(_schema, values), do: Zoi.enum(values)

  defp maybe_default(schema, %Field{default: nil}), do: schema
  defp maybe_default(schema, %Field{default: default}), do: Zoi.default(schema, default)

  defp maybe_optional(schema, %Field{required?: true}), do: schema
  defp maybe_optional(schema, %Field{}), do: Zoi.optional(schema)
end
