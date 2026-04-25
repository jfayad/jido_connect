defmodule Jido.Connect.Connection do
  @moduledoc "Durable provider grant owned by a host-app principal."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              provider: Zoi.atom(),
              profile: Zoi.atom(),
              tenant_id: Zoi.string(),
              owner_type: Zoi.enum([:user, :tenant, :system, :installation, :app_user]),
              owner_id: Zoi.string(),
              subject: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.atom(),
              credential_ref: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
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
