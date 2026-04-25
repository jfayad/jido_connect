defmodule Jido.Connect.CredentialLease do
  @moduledoc "Short-lived non-durable view of credential material."

  @schema Zoi.struct(
            __MODULE__,
            %{
              connection_id: Zoi.string(),
              expires_at: Zoi.datetime(),
              fields: Zoi.map(),
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
