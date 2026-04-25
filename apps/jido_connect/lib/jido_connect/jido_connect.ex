defmodule Jido.Connect do
  @moduledoc """
  Core integration authoring and runtime contracts.

  `use Jido.Connect` enables the Spark integration DSL. The DSL compiles into
  Zoi-backed structs under `Jido.Connect.*`; those structs are runtime truth,
  not the Spark entities.
  """

  @type field_type :: :string | :integer | :boolean | :map | {:array, field_type()}
  @type owner_type :: :user | :tenant | :system | :installation | :app_user
  @type auth_kind :: :oauth2 | :api_key | :app_installation | :none
  @type trigger_kind :: :webhook | :poll

  alias Jido.Connect.{ActionSpec, Connection, Context, CredentialLease, Field, Spec, TriggerSpec}

  use Spark.Dsl,
    default_extensions: [extensions: Jido.Connect.Dsl.Extension]

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
