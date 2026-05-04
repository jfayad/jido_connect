defmodule Jido.Connect.Google.Account do
  @moduledoc "Normalized Google account/profile metadata."

  alias Jido.Connect.Data

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              hosted_domain: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              avatar_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              locale: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              verified_email?: Zoi.boolean() |> Zoi.default(false),
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

  @doc "Normalizes Google userinfo/profile payloads."
  @spec from_userinfo(map(), map()) :: {:ok, t()}
  def from_userinfo(attrs, metadata \\ %{}) when is_map(attrs) and is_map(metadata) do
    %{
      id: Data.get(attrs, "sub") || Data.get(attrs, "id"),
      email: Data.get(attrs, "email"),
      display_name: Data.get(attrs, "name"),
      hosted_domain: Data.get(attrs, "hd"),
      avatar_url: Data.get(attrs, "picture"),
      locale: Data.get(attrs, "locale"),
      verified_email?: Data.get(attrs, "email_verified", false),
      metadata: metadata
    }
    |> Data.compact()
    |> new()
  end

  @doc "Bang variant of `from_userinfo/2`."
  @spec from_userinfo!(map(), map()) :: t()
  def from_userinfo!(attrs, metadata \\ %{}) when is_map(attrs) and is_map(metadata) do
    attrs
    |> from_userinfo(metadata)
    |> case do
      {:ok, account} -> account
      {:error, error} -> raise error
    end
  end

  @doc "Returns non-secret connection subject metadata for a Google account."
  @spec to_subject(t()) :: map()
  def to_subject(%__MODULE__{} = account) do
    %{
      google_account_id: account.id,
      email: account.email,
      display_name: account.display_name,
      hosted_domain: account.hosted_domain
    }
    |> Data.compact()
  end
end
