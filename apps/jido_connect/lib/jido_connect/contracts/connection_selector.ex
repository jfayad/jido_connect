defmodule Jido.Connect.ConnectionSelector do
  @moduledoc """
  Storage-free selector for host-owned provider connections.

  A selector describes which durable connection a host should use without
  embedding credentials or requiring `jido_connect` to own storage. Host apps
  resolve selectors into `Jido.Connect.Connection` structs, apply policy, and
  mint short-lived `Jido.Connect.CredentialLease` values.
  """

  alias Jido.Connect.{Callback, Connection, Error}

  @strategies [:per_actor, :tenant_default, :org_default, :installation, :system, :explicit]
  @owner_types [:user, :tenant, :org, :system, :installation, :app_user]

  @schema Zoi.struct(
            __MODULE__,
            %{
              provider: Zoi.atom(),
              profile: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              strategy: Zoi.enum(@strategies),
              tenant_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              actor_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_type: Zoi.enum(@owner_types) |> Zoi.nullish() |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              connection_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              required_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
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

  def explicit(provider, connection_id, attrs \\ []) do
    attrs
    |> attrs_map()
    |> Map.merge(%{provider: provider, strategy: :explicit, connection_id: connection_id})
    |> new()
  end

  def per_actor(provider, tenant_id, actor_id, attrs \\ []) do
    attrs
    |> attrs_map()
    |> Map.merge(%{
      provider: provider,
      strategy: :per_actor,
      tenant_id: tenant_id,
      actor_id: actor_id,
      owner_type: :user,
      owner_id: actor_id
    })
    |> new()
  end

  def tenant_default(provider, tenant_id, attrs \\ []) do
    attrs
    |> attrs_map()
    |> Map.merge(%{
      provider: provider,
      strategy: :tenant_default,
      tenant_id: tenant_id,
      owner_type: :tenant,
      owner_id: tenant_id
    })
    |> new()
  end

  def org_default(provider, tenant_id, org_id, attrs \\ []) do
    attrs
    |> attrs_map()
    |> Map.merge(%{
      provider: provider,
      strategy: :org_default,
      tenant_id: tenant_id,
      owner_type: :org,
      owner_id: org_id
    })
    |> new()
  end

  def installation(provider, tenant_id, installation_id, attrs \\ []) do
    attrs
    |> attrs_map()
    |> Map.merge(%{
      provider: provider,
      strategy: :installation,
      tenant_id: tenant_id,
      owner_type: :installation,
      owner_id: installation_id
    })
    |> new()
  end

  def system(provider, attrs \\ []) do
    attrs
    |> attrs_map()
    |> Map.merge(%{provider: provider, strategy: :system, owner_type: :system})
    |> new()
  end

  @doc "Builds an explicit selector from a durable connection."
  @spec from_connection(Connection.t(), keyword() | map()) :: {:ok, t()} | {:error, term()}
  def from_connection(%Connection{} = connection, attrs \\ []) do
    attrs
    |> attrs_map()
    |> Map.merge(%{
      provider: connection.provider,
      profile: connection.profile,
      strategy: :explicit,
      tenant_id: connection.tenant_id,
      owner_type: connection.owner_type,
      owner_id: connection.owner_id,
      connection_id: connection.id,
      required_scopes: connection.scopes
    })
    |> new()
  end

  @spec normalize(t() | map() | nil) :: {:ok, t()} | :error
  def normalize(%__MODULE__{} = selector), do: {:ok, selector}

  def normalize(attrs) when is_map(attrs) do
    attrs
    |> new()
    |> case do
      {:ok, selector} -> {:ok, selector}
      {:error, _error} -> :error
    end
  end

  def normalize(_other), do: :error

  @spec resolve(t() | String.t(), term(), term(), map()) ::
          {:ok, Connection.t()} | {:error, Error.error()} | :error
  def resolve(selector_or_id, resolver, operation \\ nil, config \\ %{})

  def resolve(selector_or_id, resolver, _operation, _config) when is_function(resolver, 1) do
    resolver
    |> apply_resolver([selector_or_id])
    |> normalize_connection_result()
  end

  def resolve(selector_or_id, resolver, operation, _config) when is_function(resolver, 2) do
    resolver
    |> apply_resolver([selector_or_id, operation])
    |> normalize_connection_result()
  end

  def resolve(selector_or_id, resolver, operation, config) when is_function(resolver, 3) do
    resolver
    |> apply_resolver([selector_or_id, operation, config])
    |> normalize_connection_result()
  end

  def resolve(selector_or_id, {module, function}, _operation, _config)
      when is_atom(module) and is_atom(function) do
    module
    |> apply(function, [selector_or_id])
    |> normalize_connection_result()
  end

  def resolve(selector_or_id, {module, function, extra_args}, _operation, _config)
      when is_atom(module) and is_atom(function) and is_list(extra_args) do
    module
    |> apply(function, [selector_or_id | extra_args])
    |> normalize_connection_result()
  end

  def resolve(_selector_or_id, _resolver, _operation, _config), do: :error

  @doc "Returns true when a connection satisfies this selector."
  @spec matches_connection?(t(), Connection.t()) :: boolean()
  def matches_connection?(%__MODULE__{} = selector, %Connection{} = connection) do
    selector_mismatch(selector, connection) == nil
  end

  @doc "Returns missing selector scopes for a connection."
  @spec missing_scopes(t(), Connection.t()) :: [String.t()]
  def missing_scopes(%__MODULE__{} = selector, %Connection{} = connection) do
    selector.required_scopes -- connection.scopes
  end

  @doc """
  Returns the first selector field that does not match a connection.

  Nil selector fields are treated as wildcards.
  """
  @spec selector_mismatch(t(), Connection.t()) ::
          {atom(), term(), term()} | {:required_scopes, [String.t()], [String.t()]} | nil
  def selector_mismatch(%__MODULE__{} = selector, %Connection{} = connection) do
    [
      {:connection_id, selector.connection_id, connection.id},
      {:provider, selector.provider, connection.provider},
      {:profile, selector.profile, connection.profile},
      {:tenant_id, selector.tenant_id, connection.tenant_id},
      {:owner_type, selector.owner_type, connection.owner_type},
      {:owner_id, selector.owner_id, connection.owner_id}
    ]
    |> Enum.find(fn {_field, expected, actual} -> present?(expected) and expected != actual end)
    |> case do
      nil ->
        case missing_scopes(selector, connection) do
          [] -> nil
          scopes -> {:required_scopes, scopes, connection.scopes}
        end

      mismatch ->
        mismatch
    end
  end

  defp attrs_map(attrs) when is_list(attrs), do: Map.new(attrs)
  defp attrs_map(attrs) when is_map(attrs), do: attrs

  defp apply_resolver(resolver, args) do
    case Callback.run(fn -> apply(resolver, args) end,
           phase: :connection_resolver,
           details: %{resolver: inspect(resolver)}
         ) do
      {:ok, result} -> result
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_connection_result({:error, %_{} = error}) do
    if Error.error?(error), do: {:error, error}, else: :error
  end

  defp normalize_connection_result({:ok, %Connection{} = connection}), do: {:ok, connection}
  defp normalize_connection_result(%Connection{} = connection), do: {:ok, connection}
  defp normalize_connection_result(_other), do: :error

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true
end
