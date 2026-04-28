defmodule Jido.Connect do
  @moduledoc """
  Core integration authoring and runtime contracts.

  `use Jido.Connect` enables the Spark integration DSL. The DSL compiles into
  Zoi-backed structs under `Jido.Connect.*`; those structs are runtime truth,
  not the Spark entities.

  Host apps and tests can pass either a provider module or a compiled
  `%Jido.Connect.Spec{}` into the top-level runtime functions:

      Jido.Connect.invoke(Jido.Connect.GitHub, "github.issue.list", params,
        context: context,
        credential_lease: lease
      )

  Generated Jido modules call the same runtime boundary. Provider handlers are
  invoked only after context, connection, credential lease, auth profile, and
  scope checks pass.
  """

  @typedoc "Field type supported by the Spark DSL and generated Zoi schemas."
  @type field_type :: :string | :integer | :boolean | :map | {:array, field_type()}
  @typedoc "Owner type for durable host-owned connections and credential leases."
  @type owner_type :: :user | :tenant | :org | :system | :installation | :app_user
  @typedoc "Auth profile kind supported by the core contract."
  @type auth_kind :: :oauth2 | :api_key | :app_installation | :none
  @typedoc "Trigger transport supported by generated sensors."
  @type trigger_kind :: :webhook | :poll
  @typedoc "Provider module implementing `integration/0` or an already compiled spec."
  @type integration_ref :: module() | Spec.t()
  @typedoc "Runtime options accepted by `invoke/4` and `poll/4`."
  @type runtime_opts :: keyword() | map()

  alias Jido.Connect.{
    ActionSpec,
    Authorization,
    Callback,
    Context,
    CredentialLease,
    Error,
    Field,
    Spec,
    Taxonomy,
    Telemetry,
    TriggerSpec
  }

  use Spark.Dsl,
    default_extensions: [extensions: Jido.Connect.Dsl.Extension]

  @callback integration() :: Spec.t()

  @doc """
  Returns a compiled integration spec from a provider module or spec.

  This keeps host-facing calls ergonomic while still making `%Jido.Connect.Spec{}`
  the runtime source of truth.
  """
  @spec spec(integration_ref()) :: {:ok, Spec.t()} | {:error, Error.error()}
  def spec(%Spec{} = integration), do: {:ok, integration}

  def spec(integration_module) when is_atom(integration_module) do
    with {:module, _module} <- Code.ensure_loaded(integration_module),
         true <- function_exported?(integration_module, :integration, 0),
         %Spec{} = integration <- integration_module.integration() do
      {:ok, integration}
    else
      {:error, _reason} ->
        {:error, Error.unknown_integration(integration_module)}

      false ->
        {:error, Error.unknown_integration(integration_module)}

      other ->
        {:error, Error.invalid_integration(integration_module, other)}
    end
  end

  def spec(integration_ref), do: {:error, Error.unknown_integration(integration_ref)}

  @doc "Returns the action specs for an integration."
  @spec actions(integration_ref()) :: {:ok, [ActionSpec.t()]} | {:error, Error.error()}
  def actions(integration_ref) do
    with {:ok, %Spec{actions: actions}} <- spec(integration_ref) do
      {:ok, actions}
    end
  end

  @doc "Returns the trigger specs for an integration."
  @spec triggers(integration_ref()) :: {:ok, [TriggerSpec.t()]} | {:error, Error.error()}
  def triggers(integration_ref) do
    with {:ok, %Spec{triggers: triggers}} <- spec(integration_ref) do
      {:ok, triggers}
    end
  end

  @doc "Returns the auth profiles for an integration."
  @spec auth_profiles(integration_ref()) ::
          {:ok, [Jido.Connect.AuthProfile.t()]} | {:error, Error.error()}
  def auth_profiles(integration_ref) do
    with {:ok, %Spec{auth_profiles: auth_profiles}} <- spec(integration_ref) do
      {:ok, auth_profiles}
    end
  end

  @doc "Looks up one action by id."
  @spec action(integration_ref(), String.t()) :: {:ok, ActionSpec.t()} | {:error, Error.error()}
  def action(integration_ref, action_id) when is_binary(action_id) do
    with {:ok, %Spec{} = integration} <- spec(integration_ref) do
      find_action(integration, action_id)
    end
  end

  def action(_integration_ref, action_id) do
    {:error,
     Error.validation("Action id must be a string",
       reason: :invalid_action_id,
       subject: action_id
     )}
  end

  @doc "Looks up one trigger by id."
  @spec trigger(integration_ref(), String.t()) ::
          {:ok, TriggerSpec.t()} | {:error, Error.error()}
  def trigger(integration_ref, trigger_id) when is_binary(trigger_id) do
    with {:ok, %Spec{} = integration} <- spec(integration_ref) do
      find_trigger(integration, trigger_id)
    end
  end

  def trigger(_integration_ref, trigger_id) do
    {:error,
     Error.validation("Trigger id must be a string",
       reason: :invalid_trigger_id,
       subject: trigger_id
     )}
  end

  defp find_action(%Spec{} = integration, action_id) do
    case Enum.find(integration.actions, &(&1.id == action_id)) do
      %ActionSpec{} = action -> {:ok, action}
      nil -> {:error, Error.unknown_action(action_id)}
    end
  end

  defp find_trigger(%Spec{} = integration, trigger_id) do
    case Enum.find(integration.triggers, &(&1.id == trigger_id)) do
      %TriggerSpec{} = trigger -> {:ok, trigger}
      nil -> {:error, Error.unknown_trigger(trigger_id)}
    end
  end

  @doc """
  Invokes an action through the core runtime boundary.

  `integration_ref` may be a provider module or `%Jido.Connect.Spec{}`. `opts`
  must include `:context` and `:credential_lease`; both may be structs or maps
  that coerce into `Jido.Connect.Context` and `Jido.Connect.CredentialLease`.
  """
  @spec invoke(integration_ref(), String.t(), map(), runtime_opts()) ::
          {:ok, map()} | {:error, Error.error()}
  def invoke(integration_ref, action_id, input, opts \\ [])

  def invoke(integration_ref, action_id, input, opts)
      when is_binary(action_id) and is_map(input) and (is_list(opts) or is_map(opts)) do
    with {:ok, integration} <- spec(integration_ref) do
      Telemetry.span(:invoke, telemetry_metadata(integration, action_id, opts), fn ->
        do_invoke(integration, action_id, input, opts)
      end)
    end
  end

  def invoke(_integration_ref, action_id, _input, _opts) when not is_binary(action_id) do
    {:error,
     Error.validation("Action id must be a string",
       reason: :invalid_action_id,
       subject: action_id
     )}
  end

  def invoke(_integration_ref, action_id, input, opts) do
    {:error,
     Error.validation("Invalid action invocation",
       reason: :invalid_invocation,
       subject: action_id,
       details: %{input_type: type_name(input), opts_type: type_name(opts)}
     )}
  end

  defp do_invoke(%Spec{} = integration, action_id, input, opts) do
    with {:ok, action} <- action(integration, action_id),
         {:ok, parsed_input} <- parse_schema(action.input_schema, input, :input),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- Authorization.authorize(action, parsed_input, context, lease, auth_opts(opts)),
         {:ok, output} <-
           run_action_handler(action, parsed_input, %{
             integration: integration,
             action: action,
             context: context,
             credential_lease: lease,
             credentials: lease.fields
           }),
         {:ok, parsed_output} <- parse_schema(action.output_schema, output, :output) do
      {:ok, parsed_output}
    end
  end

  @doc """
  Executes one poll trigger through the core runtime boundary.

  `opts` accepts the same `:context` and `:credential_lease` values as
  `invoke/4`, plus an optional `:checkpoint`.
  """
  @spec poll(integration_ref(), String.t(), map(), runtime_opts()) ::
          {:ok, %{signals: [map()], checkpoint: term()}} | {:error, Error.error()}
  def poll(integration_ref, trigger_id, config, opts \\ [])

  def poll(integration_ref, trigger_id, config, opts)
      when is_binary(trigger_id) and is_map(config) and (is_list(opts) or is_map(opts)) do
    with {:ok, integration} <- spec(integration_ref) do
      Telemetry.span(:poll, telemetry_metadata(integration, trigger_id, opts), fn ->
        do_poll(integration, trigger_id, config, opts)
      end)
    end
  end

  def poll(_integration_ref, trigger_id, _config, _opts) when not is_binary(trigger_id) do
    {:error,
     Error.validation("Trigger id must be a string",
       reason: :invalid_trigger_id,
       subject: trigger_id
     )}
  end

  def poll(_integration_ref, trigger_id, config, opts) do
    {:error,
     Error.validation("Invalid trigger poll",
       reason: :invalid_poll,
       subject: trigger_id,
       details: %{config_type: type_name(config), opts_type: type_name(opts)}
     )}
  end

  defp do_poll(%Spec{} = integration, trigger_id, config, opts) do
    with {:ok, trigger} <- trigger(integration, trigger_id),
         {:ok, parsed_config} <- parse_schema(trigger.config_schema, config, :config),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- Authorization.authorize(trigger, parsed_config, context, lease, auth_opts(opts)),
         {:ok, result} <-
           run_poll_handler(trigger, parsed_config, %{
             integration: integration,
             trigger: trigger,
             context: context,
             credential_lease: lease,
             credentials: lease.fields,
             checkpoint: get_option(opts, :checkpoint)
           }),
         {:ok, signals} <- validate_signals(trigger, Map.get(result, :signals, [])) do
      {:ok, %{signals: signals, checkpoint: Map.get(result, :checkpoint)}}
    end
  end

  @doc "Validates a compiled integration spec and raises on structural errors."
  @spec validate_spec!(Spec.t()) :: Spec.t()
  def validate_spec!(%Spec{} = spec) do
    auth_ids = MapSet.new(spec.auth_profiles, & &1.id)
    policy_ids = MapSet.new(spec.policies, & &1.id)

    duplicate_ids!(spec.actions, & &1.id, "action")
    duplicate_ids!(spec.triggers, & &1.id, "trigger")
    duplicate_ids!(spec.policies, & &1.id, "policy")
    duplicate_ids!(spec.schemas, & &1.id, "schema")

    validate_taxonomy!(spec)

    Enum.each(spec.actions, fn action ->
      validate_operation_taxonomy!(action)

      Enum.each(Authorization.operation_auth_profiles(action), fn auth_profile ->
        unless MapSet.member?(auth_ids, auth_profile) do
          raise Error.validation("Unknown auth profile",
                  reason: :unknown_auth_profile,
                  subject: auth_profile,
                  details: %{operation_id: action.id}
                )
        end
      end)

      if action.auth_profile not in Authorization.operation_auth_profiles(action) do
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

      validate_policy_refs!(action.policies, policy_ids, action.id)
    end)

    Enum.each(spec.triggers, fn trigger ->
      validate_operation_taxonomy!(trigger)

      Enum.each(Authorization.operation_auth_profiles(trigger), fn auth_profile ->
        unless MapSet.member?(auth_ids, auth_profile) do
          raise Error.validation("Unknown auth profile",
                  reason: :unknown_auth_profile,
                  subject: auth_profile,
                  details: %{operation_id: trigger.id}
                )
        end
      end)

      if trigger.auth_profile not in Authorization.operation_auth_profiles(trigger) do
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

      if trigger.kind == :webhook and trigger.verification in [nil, %{kind: :none}] do
        raise Error.validation("Webhook trigger must declare verification",
                reason: :missing_webhook_verification,
                subject: trigger.id
              )
      end

      validate_policy_refs!(trigger.policies, policy_ids, trigger.id)
    end)

    spec
  end

  defp validate_taxonomy!(%Spec{} = spec) do
    validate_known!(
      :category,
      spec.category,
      Taxonomy.categories(),
      spec.id,
      &Taxonomy.known_category?/1
    )

    validate_known!(:status, spec.status, Taxonomy.statuses(), spec.id, &Taxonomy.known_status?/1)

    validate_known!(
      :visibility,
      spec.visibility,
      Taxonomy.visibilities(),
      spec.id,
      &Taxonomy.known_visibility?/1
    )
  end

  defp validate_operation_taxonomy!(operation) do
    validate_required!(:resource, operation.resource, operation.id)
    validate_required!(:verb, operation.verb, operation.id)
    validate_required!(:data_classification, operation.data_classification, operation.id)

    validate_known!(
      :verb,
      operation.verb,
      Taxonomy.verbs(),
      operation.id,
      &Taxonomy.known_verb?/1
    )

    validate_known!(
      :data_classification,
      operation.data_classification,
      Taxonomy.data_classifications(),
      operation.id,
      &Taxonomy.known_data_classification?/1
    )

    if Map.has_key?(operation, :risk) do
      validate_known!(
        :risk,
        operation.risk,
        Taxonomy.risks(),
        operation.id,
        &Taxonomy.known_risk?/1
      )

      validate_known!(
        :confirmation,
        operation.confirmation,
        Taxonomy.confirmations(),
        operation.id,
        &Taxonomy.known_confirmation?/1
      )
    end
  end

  defp validate_required!(field, value, operation_id) when value in [nil, ""] do
    raise Error.validation("Operation must declare #{field}",
            reason: :missing_operation_metadata,
            subject: operation_id,
            details: %{field: field}
          )
  end

  defp validate_required!(_field, _value, _operation_id), do: :ok

  defp validate_known!(field, value, allowed, subject, known?) do
    unless known?.(value) do
      raise Error.validation("Unknown #{field}",
              reason: :unknown_taxonomy_value,
              subject: subject,
              details: %{field: field, value: value, allowed: allowed}
            )
    end
  end

  defp validate_policy_refs!(policies, policy_ids, operation_id) do
    Enum.each(policies || [], fn policy ->
      unless MapSet.member?(policy_ids, policy) do
        raise Error.validation("Unknown policy",
                reason: :unknown_policy,
                subject: policy,
                details: %{operation_id: operation_id}
              )
      end
    end)
  end

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

  defp fetch_context(opts) do
    case fetch_option(opts, :context) do
      {:ok, %Context{} = context} ->
        {:ok, context}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> Context.new() |> normalize_schema_result(:context)

      :error ->
        {:error, Error.context_required()}
    end
  end

  defp fetch_credential_lease(opts) do
    case fetch_option(opts, :credential_lease) do
      {:ok, %CredentialLease{} = lease} ->
        {:ok, lease}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> CredentialLease.new() |> normalize_schema_result(:credential_lease)

      :error ->
        {:error, Error.credential_lease_required()}
    end
  end

  defp run_action_handler(%ActionSpec{} = action, input, context) do
    with {:ok, result} <-
           Callback.call(action.handler, :run, [input, context],
             phase: :handler,
             details: %{operation_id: action.id}
           ) do
      normalize_handler_result(result, :handler, action.id)
    end
  end

  defp run_poll_handler(%TriggerSpec{} = trigger, config, context) do
    with {:ok, result} <-
           Callback.call(trigger.handler, :poll, [config, context],
             phase: :handler,
             details: %{operation_id: trigger.id}
           ) do
      normalize_handler_result(result, :handler, trigger.id)
    end
  end

  defp normalize_handler_result({:ok, value}, _phase, _operation_id), do: {:ok, value}

  defp normalize_handler_result({:error, %_module{} = error}, phase, operation_id) do
    if Error.error?(error) do
      {:error, error}
    else
      normalize_handler_result({:error, Map.from_struct(error)}, phase, operation_id)
    end
  end

  defp normalize_handler_result({:error, reason}, phase, operation_id) do
    {:error,
     Error.execution("Provider handler failed",
       phase: phase,
       details: %{
         operation_id: operation_id,
         error: Jido.Connect.Sanitizer.sanitize(reason, :transport)
       }
     )}
  end

  defp normalize_handler_result(result, phase, operation_id) do
    {:error,
     Error.execution("Provider handler returned an invalid result",
       phase: phase,
       details: %{
         operation_id: operation_id,
         returned: Jido.Connect.Sanitizer.sanitize(result, :transport)
       }
     )}
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

  defp fetch_option(opts, key) when is_list(opts), do: Keyword.fetch(opts, key)
  defp fetch_option(opts, key) when is_map(opts), do: Map.fetch(opts, key)

  defp get_option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp get_option(opts, key) when is_map(opts), do: Map.get(opts, key)

  defp auth_opts(opts) do
    %{
      policy: get_option(opts, :policy),
      policy_context: get_option(opts, :policy_context)
    }
  end

  defp telemetry_metadata(%Spec{} = integration, operation_id, opts) do
    context = get_option(opts, :context)
    lease = get_option(opts, :credential_lease)
    connection = context_connection(context)

    %{
      integration_id: integration.id,
      operation_id: operation_id,
      tenant_id: context_field(context, :tenant_id),
      actor_type: actor_type(context),
      connection_id: connection_field(connection, :id),
      auth_profile: connection_field(connection, :profile),
      credential_lease_connection_id: credential_lease_connection_id(lease)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp context_connection(%Context{connection: connection}), do: connection
  defp context_connection(%{connection: connection}), do: connection
  defp context_connection(_context), do: nil

  defp context_field(%Context{} = context, field), do: Map.get(context, field)
  defp context_field(context, field) when is_map(context), do: Map.get(context, field)
  defp context_field(_context, _field), do: nil

  defp actor_type(%Context{actor: actor}), do: actor_type(actor)
  defp actor_type(%{actor: actor}), do: actor_type(actor)
  defp actor_type(%{type: type}), do: type
  defp actor_type(%{"type" => type}), do: type
  defp actor_type(_context), do: nil

  defp connection_field(%Jido.Connect.Connection{} = connection, field),
    do: Map.get(connection, field)

  defp connection_field(connection, field) when is_map(connection), do: Map.get(connection, field)
  defp connection_field(_connection, _field), do: nil

  defp credential_lease_connection_id(%CredentialLease{connection_id: connection_id}),
    do: connection_id

  defp credential_lease_connection_id(%{connection_id: connection_id}), do: connection_id
  defp credential_lease_connection_id(_lease), do: nil

  defp type_name(value) when is_map(value), do: :map
  defp type_name(value) when is_list(value), do: :list
  defp type_name(value) when is_binary(value), do: :string
  defp type_name(value) when is_atom(value), do: :atom
  defp type_name(value) when is_integer(value), do: :integer
  defp type_name(value) when is_float(value), do: :float
  defp type_name(_value), do: :unknown

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
