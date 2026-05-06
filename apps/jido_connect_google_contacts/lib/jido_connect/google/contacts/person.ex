defmodule Jido.Connect.Google.Contacts.Person do
  @moduledoc "Normalized Google Contacts person metadata."

  alias Jido.Connect.Google.Contacts.{Email, Organization, Phone}

  @schema Zoi.struct(
            __MODULE__,
            %{
              resource_name: Zoi.string(),
              person_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              given_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              family_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              names: Zoi.list(Zoi.map()) |> Zoi.default([]),
              email_addresses: Zoi.list(Email.schema()) |> Zoi.default([]),
              phone_numbers: Zoi.list(Phone.schema()) |> Zoi.default([]),
              organizations: Zoi.list(Organization.schema()) |> Zoi.default([]),
              memberships: Zoi.list(Zoi.map()) |> Zoi.default([]),
              photos: Zoi.list(Zoi.map()) |> Zoi.default([]),
              addresses: Zoi.list(Zoi.map()) |> Zoi.default([]),
              birthdays: Zoi.list(Zoi.map()) |> Zoi.default([]),
              urls: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
