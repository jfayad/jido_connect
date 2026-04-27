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

  alias Jido.Connect.{
    ActionSpec,
    Connection,
    Context,
    CredentialLease,
    Error,
    Field,
    ScopeRequirements,
    Spec,
    TriggerSpec
  }

  use Spark.Dsl,
    default_extensions: [extensions: Jido.Connect.Dsl.Extension]

  @callback integration() :: Spec.t()

  def action(%Spec{} = integration, action_id) when is_binary(action_id) do
    case Enum.find(integration.actions, &(&1.id == action_id)) do
      %ActionSpec{} = action -> {:ok, action}
      nil -> {:error, Error.unknown_action(action_id)}
    end
  end

  def trigger(%Spec{} = integration, trigger_id) when is_binary(trigger_id) do
    case Enum.find(integration.triggers, &(&1.id == trigger_id)) do
      %TriggerSpec{} = trigger -> {:ok, trigger}
      nil -> {:error, Error.unknown_trigger(trigger_id)}
    end
  end

  def invoke(%Spec{} = integration, action_id, input, opts \\ [])
      when is_binary(action_id) and is_map(input) do
    with {:ok, action} <- action(integration, action_id),
         {:ok, parsed_input} <- parse_schema(action.input_schema, input, :input),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- authorize_connection(action, parsed_input, context, lease),
         {:ok, output} <-
           action.handler.run(parsed_input, %{
             integration: integration,
             action: action,
             context: context,
             credentials: lease.fields
           }),
         {:ok, parsed_output} <- parse_schema(action.output_schema, output, :output) do
      {:ok, parsed_output}
    end
  end

  def poll(%Spec{} = integration, trigger_id, config, opts \\ [])
      when is_binary(trigger_id) and is_map(config) do
    with {:ok, trigger} <- trigger(integration, trigger_id),
         {:ok, parsed_config} <- parse_schema(trigger.config_schema, config, :config),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- authorize_trigger_connection(trigger, parsed_config, context, lease),
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
      Enum.each(operation_auth_profiles(action), fn auth_profile ->
        unless MapSet.member?(auth_ids, auth_profile) do
          raise Error.validation("Unknown auth profile",
                  reason: :unknown_auth_profile,
                  subject: auth_profile,
                  details: %{operation_id: action.id}
                )
        end
      end)

      if action.auth_profile not in operation_auth_profiles(action) do
        raise Error.validation("Unknown auth profile",
                reason: :unknown_auth_profile,
                subject: action.auth_profile,
                details: %{operation_id: action.id}
              )
      end

      if action.mutation? and action.confirmation in [nil, :none] do
        raise Error.validation("Mutation action must declare confirmation policy",
                reason: :missing_confirmation_policy,
                subject: action.id
              )
      end
    end)

    Enum.each(spec.triggers, fn trigger ->
      Enum.each(operation_auth_profiles(trigger), fn auth_profile ->
        unless MapSet.member?(auth_ids, auth_profile) do
          raise Error.validation("Unknown auth profile",
                  reason: :unknown_auth_profile,
                  subject: auth_profile,
                  details: %{operation_id: trigger.id}
                )
        end
      end)

      if trigger.auth_profile not in operation_auth_profiles(trigger) do
        raise Error.validation("Unknown auth profile",
                reason: :unknown_auth_profile,
                subject: trigger.auth_profile,
                details: %{operation_id: trigger.id}
              )
      end

      if trigger.kind == :poll and (is_nil(trigger.checkpoint) or is_nil(trigger.dedupe)) do
        raise Error.validation("Poll trigger must declare checkpoint and dedupe",
                reason: :missing_poll_contract,
                subject: trigger.id
              )
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

  defp fetch_context(opts) do
    case Keyword.fetch(opts, :context) do
      {:ok, %Context{} = context} ->
        {:ok, context}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> Context.new() |> normalize_schema_result(:context)

      :error ->
        {:error, Error.context_required()}
    end
  end

  defp fetch_credential_lease(opts) do
    case Keyword.fetch(opts, :credential_lease) do
      {:ok, %CredentialLease{} = lease} ->
        {:ok, lease}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> CredentialLease.new() |> normalize_schema_result(:credential_lease)

      :error ->
        {:error, Error.credential_lease_required()}
    end
  end

  defp authorize_connection(
         %ActionSpec{} = action,
         input,
         %Context{} = context,
         %CredentialLease{} = lease
       ) do
    connection =
      case context.connection do
        %Connection{} = connection -> connection
        _other -> nil
      end

    cond do
      DateTime.compare(lease.expires_at, DateTime.utc_now()) != :gt ->
        {:error, Error.credential_lease_expired(lease.expires_at)}

      is_nil(connection) ->
        {:error, Error.connection_required(%{action_id: action.id})}

      connection.status != :connected ->
        {:error,
         Error.connection_required(%{
           action_id: action.id,
           connection_id: connection.id,
           status: connection.status
         })}

      connection.id != lease.connection_id ->
        {:error, Error.credential_connection_mismatch(connection.id, lease.connection_id)}

      connection.profile not in operation_auth_profiles(action) ->
        {:error,
         Error.unsupported_auth_profile(
           connection.id,
           connection.profile,
           operation_auth_profiles(action)
         )}

      true ->
        with {:ok, required_scopes} <-
               ScopeRequirements.required_scopes(action, input, connection) do
          missing_scopes = required_scopes -- connection.scopes

          if missing_scopes == [] do
            :ok
          else
            {:error, Error.missing_scopes(connection.id, missing_scopes)}
          end
        end
    end
  end

  defp authorize_trigger_connection(
         %TriggerSpec{} = trigger,
         config,
         %Context{} = context,
         %CredentialLease{} = lease
       ) do
    action_like = %ActionSpec{
      id: trigger.id,
      name: trigger.name,
      label: trigger.label,
      auth_profile: trigger.auth_profile,
      auth_profiles: trigger.auth_profiles,
      handler: trigger.handler,
      input_schema: trigger.config_schema,
      output_schema: trigger.signal_schema,
      scopes: trigger.scopes,
      scope_resolver: trigger.scope_resolver
    }

    authorize_connection(action_like, config, context, lease)
  end

  defp operation_auth_profiles(operation) do
    case Map.get(operation, :auth_profiles, []) do
      [] -> [operation.auth_profile]
      profiles -> profiles
    end
  end

  defp validate_signals(%TriggerSpec{} = trigger, signals) when is_list(signals) do
    Enum.reduce_while(signals, {:ok, []}, fn signal, {:ok, acc} ->
      case Zoi.parse(trigger.signal_schema, signal) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        {:error, error} -> {:halt, {:error, Error.zoi(:signal, error, %{trigger_id: trigger.id})}}
      end
    end)
  end

  defp parse_schema(schema, value, reason) do
    case Zoi.parse(schema, value) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, errors} -> {:error, Error.zoi(reason, errors)}
    end
  end

  defp normalize_schema_result({:ok, parsed}, _reason), do: {:ok, parsed}
  defp normalize_schema_result({:error, errors}, reason), do: {:error, Error.zoi(reason, errors)}

  defp duplicate_ids!(items, id_fun, label) do
    ids = Enum.map(items, id_fun)

    case ids -- Enum.uniq(ids) do
      [] ->
        :ok

      duplicates ->
        raise Error.validation("Duplicate #{label} ids",
                reason: :duplicate_id,
                subject: label,
                details: %{duplicates: Enum.uniq(duplicates)}
              )
    end
  end
end
