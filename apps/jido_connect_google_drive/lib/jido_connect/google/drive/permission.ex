defmodule Jido.Connect.Google.Drive.Permission do
  @moduledoc "Normalized Google Drive permission metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              permission_id: Zoi.string(),
              type: Zoi.string(),
              role: Zoi.string(),
              email_address: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              domain: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              allow_file_discovery?: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              deleted?: Zoi.boolean() |> Zoi.default(false),
              expiration_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
