defmodule Jido.Connect do
  @moduledoc """
  Core integration authoring and runtime contracts.

  `use Jido.Connect` enables the Spark integration DSL. The DSL compiles
  into the Zoi-backed structs nested in this module; those structs are runtime
  truth, not the Spark entities.
  """

  @type field_type :: :string | :integer | :boolean | :map | {:array, field_type()}
  @type owner_type :: :user | :tenant | :system | :installation | :app_user
  @type auth_kind :: :oauth2 | :api_key | :app_installation | :none
  @type trigger_kind :: :webhook | :poll

  use Spark.Dsl,
    default_extensions: [extensions: Jido.Connect.Dsl.Extension]

  defmodule Field do
    @moduledoc "Input, output, config, and signal field contract."

    @schema Zoi.struct(
              __MODULE__,
              %{
                name: Zoi.atom(),
                type: Zoi.any(),
                description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                example: Zoi.any() |> Zoi.optional(),
                default: Zoi.any() |> Zoi.optional(),
                enum: Zoi.list(Zoi.any()) |> Zoi.nullish() |> Zoi.optional(),
                required?: Zoi.boolean() |> Zoi.default(false),
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

  defmodule AuthProfile do
    @moduledoc "Supported provider authorization profile."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.atom(),
                kind: Zoi.enum([:oauth2, :api_key, :app_installation, :none]),
                owner: Zoi.enum([:user, :tenant, :system, :installation, :app_user]),
                subject: Zoi.atom(),
                label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                authorize_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                token_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                callback_path: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                token_field: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                refresh_token_field: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
                default_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
                fields: Zoi.list(Zoi.atom()) |> Zoi.default([]),
                pkce?: Zoi.boolean() |> Zoi.default(false),
                refresh?: Zoi.boolean() |> Zoi.default(false),
                revoke?: Zoi.boolean() |> Zoi.default(false),
                default?: Zoi.boolean() |> Zoi.default(false),
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

  defmodule ActionSpec do
    @moduledoc "Provider action contract."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.string(),
                name: Zoi.atom(),
                label: Zoi.string(),
                description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                auth_profile: Zoi.atom(),
                handler: Zoi.module(),
                input: Zoi.list(Field.schema()) |> Zoi.default([]),
                output: Zoi.list(Field.schema()) |> Zoi.default([]),
                input_schema: Zoi.any(),
                output_schema: Zoi.any(),
                scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
                mutation?: Zoi.boolean() |> Zoi.default(false),
                risk: Zoi.atom() |> Zoi.default(:read),
                confirmation: Zoi.atom() |> Zoi.default(:none),
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

  defmodule TriggerSpec do
    @moduledoc "Provider trigger contract for webhook and poll sources."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.string(),
                name: Zoi.atom(),
                kind: Zoi.enum([:webhook, :poll]),
                label: Zoi.string(),
                description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                auth_profile: Zoi.atom(),
                handler: Zoi.module(),
                config: Zoi.list(Field.schema()) |> Zoi.default([]),
                signal: Zoi.list(Field.schema()) |> Zoi.default([]),
                config_schema: Zoi.any(),
                signal_schema: Zoi.any(),
                scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
                verification: Zoi.map() |> Zoi.default(%{kind: :none}),
                dedupe: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
                checkpoint: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                interval_ms: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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

  defmodule Spec do
    @moduledoc "Complete integration provider contract."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.atom(),
                name: Zoi.string(),
                category: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                docs: Zoi.list(Zoi.string()) |> Zoi.default([]),
                auth_profiles: Zoi.list(AuthProfile.schema()) |> Zoi.default([]),
                actions: Zoi.list(ActionSpec.schema()) |> Zoi.default([]),
                triggers: Zoi.list(TriggerSpec.schema()) |> Zoi.default([]),
                metadata: Zoi.map() |> Zoi.default(%{})
              },
              coerce: true
            )

    @type t :: unquote(Zoi.type_spec(@schema))
    @enforce_keys Zoi.Struct.enforce_keys(@schema)
    defstruct Zoi.Struct.struct_fields(@schema)

    def schema, do: @schema
    def new!(attrs), do: Zoi.parse!(@schema, attrs) |> Jido.Connect.validate_spec!()

    def new(attrs) do
      {:ok, new!(attrs)}
    rescue
      error -> {:error, error}
    end
  end

  defmodule Context do
    @moduledoc "Host-provided tenant, actor, and connection selection context."

    @schema Zoi.struct(
              __MODULE__,
              %{
                tenant_id: Zoi.string(),
                actor: Zoi.map(),
                connection: Zoi.any() |> Zoi.optional(),
                claims: Zoi.map() |> Zoi.default(%{}),
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

  defmodule Connection do
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

  defmodule CredentialLease do
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

  defmodule Run do
    @moduledoc "Minimal action or trigger execution record."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.string(),
                integration_id: Zoi.atom(),
                operation_id: Zoi.string(),
                tenant_id: Zoi.string(),
                actor: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
                connection_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                input_hash: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                status: Zoi.atom(),
                inserted_at: Zoi.datetime(),
                updated_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
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

  defmodule Event do
    @moduledoc "Minimal redacted execution event record."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.string(),
                run_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                trigger_event_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                type: Zoi.any(),
                timestamp: Zoi.datetime(),
                payload: Zoi.map() |> Zoi.default(%{}),
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

  @callback integration() :: Spec.t()

  def action(%Spec{} = integration, action_id) when is_binary(action_id) do
    case Enum.find(integration.actions, &(&1.id == action_id)) do
      %ActionSpec{} = action -> {:ok, action}
      nil -> {:error, :unknown_action}
    end
  end

  def trigger(%Spec{} = integration, trigger_id) when is_binary(trigger_id) do
    case Enum.find(integration.triggers, &(&1.id == trigger_id)) do
      %TriggerSpec{} = trigger -> {:ok, trigger}
      nil -> {:error, :unknown_trigger}
    end
  end

  def invoke(%Spec{} = integration, action_id, input, opts \\ [])
      when is_binary(action_id) and is_map(input) do
    with {:ok, action} <- action(integration, action_id),
         {:ok, parsed_input} <- Zoi.parse(action.input_schema, input),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- authorize_connection(action, context, lease),
         {:ok, output} <-
           action.handler.run(parsed_input, %{
             integration: integration,
             action: action,
             context: context,
             credentials: lease.fields
           }),
         {:ok, parsed_output} <- Zoi.parse(action.output_schema, output) do
      {:ok, parsed_output}
    end
  end

  def poll(%Spec{} = integration, trigger_id, config, opts \\ [])
      when is_binary(trigger_id) and is_map(config) do
    with {:ok, trigger} <- trigger(integration, trigger_id),
         {:ok, parsed_config} <- Zoi.parse(trigger.config_schema, config),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- authorize_trigger_connection(trigger, context, lease),
         {:ok, result} <-
           trigger.handler.poll(parsed_config, %{
             integration: integration,
             trigger: trigger,
             context: context,
             credentials: lease.fields,
             checkpoint: Keyword.get(opts, :checkpoint)
           }),
         {:ok, signals} <- validate_signals(trigger, Map.get(result, :signals, [])) do
      {:ok, %{signals: signals, checkpoint: Map.get(result, :checkpoint)}}
    end
  end

  def validate_spec!(%Spec{} = spec) do
    auth_ids = MapSet.new(spec.auth_profiles, & &1.id)

    duplicate_ids!(spec.actions, & &1.id, "action")
    duplicate_ids!(spec.triggers, & &1.id, "trigger")

    Enum.each(spec.actions, fn action ->
      unless MapSet.member?(auth_ids, action.auth_profile) do
        raise ArgumentError,
              "unknown auth profile #{inspect(action.auth_profile)} for #{action.id}"
      end

      if action.mutation? and action.confirmation in [nil, :none] do
        raise ArgumentError, "mutation action #{action.id} must declare confirmation policy"
      end
    end)

    Enum.each(spec.triggers, fn trigger ->
      unless MapSet.member?(auth_ids, trigger.auth_profile) do
        raise ArgumentError,
              "unknown auth profile #{inspect(trigger.auth_profile)} for #{trigger.id}"
      end

      if trigger.kind == :poll and (is_nil(trigger.checkpoint) or is_nil(trigger.dedupe)) do
        raise ArgumentError, "poll trigger #{trigger.id} must declare checkpoint and dedupe"
      end
    end)

    spec
  end

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
    raise ArgumentError, "unsupported integration field type: #{inspect(type)}"
  end

  defp maybe_enum(schema, nil), do: schema
  defp maybe_enum(_schema, values), do: Zoi.enum(values)

  defp maybe_default(schema, %Field{default: nil}), do: schema
  defp maybe_default(schema, %Field{default: default}), do: Zoi.default(schema, default)

  defp maybe_optional(schema, %Field{required?: true}), do: schema
  defp maybe_optional(schema, %Field{}), do: Zoi.optional(schema)

  defp fetch_context(opts) do
    case Keyword.fetch(opts, :context) do
      {:ok, %Context{} = context} -> {:ok, context}
      {:ok, attrs} when is_map(attrs) -> Context.new(attrs)
      :error -> {:error, :context_required}
    end
  end

  defp fetch_credential_lease(opts) do
    case Keyword.fetch(opts, :credential_lease) do
      {:ok, %CredentialLease{} = lease} -> {:ok, lease}
      {:ok, attrs} when is_map(attrs) -> CredentialLease.new(attrs)
      :error -> {:error, :credential_lease_required}
    end
  end

  defp authorize_connection(
         %ActionSpec{} = action,
         %Context{} = context,
         %CredentialLease{} = lease
       ) do
    connection =
      case context.connection do
        %Connection{} = connection -> connection
        _other -> nil
      end

    missing_scopes = if connection, do: action.scopes -- connection.scopes, else: []

    cond do
      is_nil(connection) ->
        :ok

      connection.status != :connected ->
        {:error, :connection_required}

      connection.id != lease.connection_id ->
        {:error, :credential_connection_mismatch}

      missing_scopes != [] ->
        {:error, {:missing_scopes, missing_scopes}}

      true ->
        :ok
    end
  end

  defp authorize_trigger_connection(
         %TriggerSpec{} = trigger,
         %Context{} = context,
         %CredentialLease{} = lease
       ) do
    action_like = %ActionSpec{
      id: trigger.id,
      name: trigger.name,
      label: trigger.label,
      auth_profile: trigger.auth_profile,
      handler: trigger.handler,
      input_schema: trigger.config_schema,
      output_schema: trigger.signal_schema,
      scopes: trigger.scopes
    }

    authorize_connection(action_like, context, lease)
  end

  defp validate_signals(%TriggerSpec{} = trigger, signals) when is_list(signals) do
    Enum.reduce_while(signals, {:ok, []}, fn signal, {:ok, acc} ->
      case Zoi.parse(trigger.signal_schema, signal) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp duplicate_ids!(items, id_fun, label) do
    ids = Enum.map(items, id_fun)

    case ids -- Enum.uniq(ids) do
      [] ->
        :ok

      duplicates ->
        raise ArgumentError, "duplicate #{label} ids: #{inspect(Enum.uniq(duplicates))}"
    end
  end
end
