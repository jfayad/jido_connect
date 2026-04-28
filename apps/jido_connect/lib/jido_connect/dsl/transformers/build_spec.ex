defmodule Jido.Connect.Dsl.Transformers.BuildSpec do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias Jido.Connect
  alias Jido.Connect.Dsl
  alias Jido.Connect.Dsl.OperationRules
  alias Jido.Connect.Jido.{ActionProjection, PluginProjection, SensorProjection}
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    with :ok <- validate_operation_rules(dsl_state),
         {:ok, integration_attrs} <- integration_attrs(dsl_state),
         {:ok, spec} <- build_spec(dsl_state, integration_attrs) do
      integration_module = Transformer.get_persisted(dsl_state, :module)
      projection = jido_projection(integration_module, spec)
      generated_modules = generated_modules_ast(projection)

      dsl_state =
        dsl_state
        |> Transformer.persist(:jido_connect_spec, spec)
        |> Transformer.persist(:jido_projection, projection)
        |> Transformer.eval(
          [],
          quote do
            @behaviour Jido.Connect

            @impl Jido.Connect
            def integration, do: unquote(Macro.escape(spec))

            def jido_action_modules,
              do: unquote(Macro.escape(Enum.map(projection.actions, & &1.module)))

            def jido_sensor_modules,
              do: unquote(Macro.escape(Enum.map(projection.sensors, & &1.module)))

            def jido_plugin_module, do: unquote(projection.module)

            def jido_projection, do: unquote(Macro.escape(projection))

            unquote_splicing(generated_modules)
          end
        )

      {:ok, dsl_state}
    end
  end

  defp validate_operation_rules(dsl_state) do
    case OperationRules.violations(dsl_state, Transformer) do
      [] -> :ok
      [violation | _] -> {:error, violation.message}
    end
  end

  defp integration_attrs(dsl_state) do
    id = Transformer.get_option(dsl_state, [:integration], :id)
    name = Transformer.get_option(dsl_state, [:integration], :name)

    if id && name do
      integration_metadata = Transformer.get_option(dsl_state, [:integration], :metadata, %{})
      catalog_metadata = Transformer.get_option(dsl_state, [:catalog], :metadata, %{})

      {:ok,
       %{
         id: id,
         name: name,
         description:
           Transformer.get_option(dsl_state, [:catalog], :description) ||
             Transformer.get_option(dsl_state, [:integration], :description),
         category: Transformer.get_option(dsl_state, [:integration], :category),
         package: Transformer.get_option(dsl_state, [:catalog], :package),
         status: Transformer.get_option(dsl_state, [:catalog], :status, :available),
         tags: Transformer.get_option(dsl_state, [:catalog], :tags, []),
         visibility: Transformer.get_option(dsl_state, [:catalog], :visibility, :public),
         docs: Transformer.get_option(dsl_state, [:integration], :docs, []),
         metadata: Map.merge(integration_metadata, catalog_metadata)
       }}
    else
      {:error, "integration section with id and name is required"}
    end
  end

  defp build_spec(dsl_state, integration_attrs) do
    auth_profiles =
      dsl_state
      |> Transformer.get_entities([:auth])
      |> Enum.map(&auth_profile!/1)

    capabilities =
      dsl_state
      |> Transformer.get_entities([:catalog])
      |> Enum.map(&capability!(&1, integration_attrs))

    policies =
      dsl_state
      |> Transformer.get_entities([:policies])
      |> Enum.map(&policy_requirement!/1)

    schemas =
      dsl_state
      |> Transformer.get_entities([:schemas])
      |> Enum.map(&named_schema!/1)

    schemas_by_id = Map.new(schemas, &{&1.id, &1})

    actions =
      dsl_state
      |> Transformer.get_entities([:actions])
      |> Enum.map(&action_spec!(&1, integration_attrs.id, schemas_by_id, auth_profiles))

    triggers =
      dsl_state
      |> Transformer.get_entities([:triggers])
      |> Enum.map(&trigger_spec!(&1, integration_attrs.id, schemas_by_id, auth_profiles))

    spec =
      integration_attrs
      |> Map.put(:capabilities, capabilities)
      |> Map.put(:policies, policies)
      |> Map.put(:schemas, schemas)
      |> Map.put(:auth_profiles, auth_profiles)
      |> Map.put(:actions, actions)
      |> Map.put(:triggers, triggers)
      |> Connect.Spec.new!()

    {:ok, spec}
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp auth_profile!(%Dsl.AuthProfile{} = profile) do
    attrs = Map.from_struct(profile)
    credential_fields = credential_fields(attrs)

    attrs
    |> Map.put(:credential_fields, credential_fields)
    |> Map.put(:lease_fields, non_empty(attrs.lease_fields, credential_fields))
    |> Map.put(:fields, credential_fields)
    |> Map.put(:setup, attrs.setup || setup_for(attrs.kind))
    |> Connect.AuthProfile.new!()
  end

  defp capability!(%Dsl.Capability{} = capability, integration_attrs) do
    Connect.ConnectorCapability.new!(%{
      id: capability.id || "#{integration_attrs.id}.#{capability.name}",
      provider: integration_attrs.id,
      kind: capability.kind,
      feature: capability.feature || capability.name,
      label: capability.label || humanize(capability.name),
      description: capability.description,
      status: capability.status || integration_attrs.status || :available,
      metadata: capability.metadata
    })
  end

  defp policy_requirement!(%Dsl.PolicyRequirement{} = policy) do
    Connect.PolicyRequirement.new!(%{
      id: policy.id || policy.name,
      label: policy.label || humanize(policy.name),
      description: policy.description,
      subject: policy.subject,
      owner: policy.owner,
      decision: policy.decision,
      metadata: policy.metadata
    })
  end

  defp named_schema!(%Dsl.NamedSchema{} = schema) do
    fields = fields(schema.fields)

    Connect.NamedSchema.new!(%{
      id: schema.name,
      label: schema.label || humanize(schema.name),
      description: schema.description,
      fields: fields,
      zoi_schema: Connect.zoi_schema_from_fields(fields),
      metadata: schema.metadata
    })
  end

  defp action_spec!(%Dsl.Action{} = action, integration_id, schemas_by_id, provider_auth_profiles) do
    input = fields(action.input, action.input_schema, schemas_by_id, :input, action.name)
    output = fields(action.output, action.output_schema, schemas_by_id, :output, action.name)
    default_auth_profile = default_auth_profile(provider_auth_profiles)
    {auth_profile, auth_profiles} = auth_profiles(access_auth(action), default_auth_profile)
    requirements = requirements(action.requirements, action.access)
    policies = access_policies(action)
    {mutation?, risk, confirmation} = effect(action)

    Connect.ActionSpec.new!(%{
      id: action.id || "#{integration_id}.#{action.name}",
      name: action.name,
      label: action.label || humanize(action.name),
      description: action.description,
      resource: action.resource,
      verb: action.verb,
      data_classification: action.data_classification,
      auth_profile: auth_profile,
      auth_profiles: auth_profiles,
      policies: policies,
      handler: action.handler,
      input: input,
      output: output,
      input_schema: Connect.zoi_schema_from_fields(input),
      output_schema: Connect.zoi_schema_from_fields(output),
      scopes: requirements.scopes,
      scope_resolver: requirements.dynamic_scopes,
      mutation?: mutation?,
      risk: risk,
      confirmation: confirmation,
      metadata: action.metadata
    })
  end

  defp trigger_spec!(
         %Dsl.Trigger{} = trigger,
         integration_id,
         schemas_by_id,
         provider_auth_profiles
       ) do
    config = fields(trigger.config, trigger.config_schema, schemas_by_id, :config, trigger.name)
    signal = fields(trigger.signal, trigger.signal_schema, schemas_by_id, :signal, trigger.name)
    default_auth_profile = default_auth_profile(provider_auth_profiles)
    {auth_profile, auth_profiles} = auth_profiles(access_auth(trigger), default_auth_profile)
    requirements = requirements(trigger.requirements, trigger.access)
    policies = access_policies(trigger)

    Connect.TriggerSpec.new!(%{
      id: trigger.id || "#{integration_id}.#{trigger.name}",
      name: trigger.name,
      kind: trigger.kind,
      label: trigger.label || humanize(trigger.name),
      description: trigger.description,
      resource: trigger.resource,
      verb: trigger.verb,
      data_classification: trigger.data_classification,
      auth_profile: auth_profile,
      auth_profiles: auth_profiles,
      policies: policies,
      handler: trigger.handler,
      config: config,
      signal: signal,
      config_schema: Connect.zoi_schema_from_fields(config),
      signal_schema: Connect.zoi_schema_from_fields(signal),
      scopes: requirements.scopes,
      scope_resolver: requirements.dynamic_scopes,
      verification: trigger.verification || %{kind: :none},
      dedupe: trigger.dedupe,
      checkpoint: trigger.checkpoint,
      interval_ms: trigger.interval_ms,
      metadata: trigger.metadata
    })
  end

  defp default_auth_profile([]), do: :user

  defp default_auth_profile(auth_profiles) do
    default_profile = Enum.find(auth_profiles, & &1.default?)
    (default_profile || List.first(auth_profiles)).id
  end

  defp auth_profiles(%Dsl.AuthProfiles{profiles: profiles, default: default}, fallback) do
    profiles = List.wrap(profiles || [])
    primary = default || List.first(profiles) || fallback

    {primary,
     [primary | profiles]
     |> Enum.reject(&is_nil/1)
     |> Enum.uniq()}
  end

  defp auth_profiles(nil, fallback), do: {fallback, [fallback]}

  defp requirements(%Dsl.Requirements{} = requirements, _access), do: requirements

  defp requirements(nil, %Dsl.Access{scopes: %Dsl.ScopeRequirements{} = scopes}) do
    %Dsl.Requirements{scopes: scopes.scopes, dynamic_scopes: scopes.resolver}
  end

  defp requirements(nil, _access) do
    %Dsl.Requirements{scopes: [], dynamic_scopes: nil}
  end

  defp access_auth(%{access: %Dsl.Access{auth: %Dsl.AuthProfiles{} = auth}}), do: auth
  defp access_auth(%{auth_profiles: %Dsl.AuthProfiles{} = auth}), do: auth
  defp access_auth(_operation), do: nil

  defp access_policies(%{access: %Dsl.Access{policies: policies}}) when policies != [],
    do: policies

  defp access_policies(%{policies: policies}), do: policies

  defp effect(%Dsl.Action{effect: %Dsl.Effect{} = effect}) do
    risk = effect.risk || :read
    mutation? = if is_nil(effect.mutation?), do: mutating_risk?(risk), else: effect.mutation?
    confirmation = effect.confirmation || if(mutation?, do: :required_for_ai, else: :none)

    {mutation?, risk, confirmation}
  end

  defp effect(%Dsl.Action{} = action), do: {action.mutation?, action.risk, action.confirmation}

  defp mutating_risk?(risk), do: risk not in [:read, :metadata]

  defp credential_fields(attrs) do
    attrs.credential_fields
    |> non_empty(attrs.fields || [])
    |> non_empty([attrs.token_field, attrs.refresh_token_field])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp non_empty(value, fallback) when value in [nil, []], do: fallback || []
  defp non_empty(value, _fallback), do: value

  defp setup_for(:oauth2), do: :oauth2_authorization_code
  defp setup_for(:app_installation), do: :app_installation
  defp setup_for(:api_key), do: :api_key
  defp setup_for(:none), do: :none

  defp fields(%Dsl.FieldGroup{fields: fields}), do: fields || []
  defp fields(nil), do: []
  defp fields(fields) when is_list(fields), do: fields

  defp fields(inline_fields, schema_ref, schemas_by_id, field_group, operation_name) do
    inline_fields = fields(inline_fields)

    cond do
      is_nil(schema_ref) ->
        inline_fields

      inline_fields != [] ->
        raise ArgumentError,
              "#{field_group} for #{operation_name} cannot declare both inline fields and schema #{inspect(schema_ref)}"

      schema = Map.get(schemas_by_id, schema_ref) ->
        schema.fields

      true ->
        raise ArgumentError,
              "Unknown schema #{inspect(schema_ref)} referenced by #{field_group} for #{operation_name}"
    end
  end

  defp humanize(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp jido_projection(integration_module, %Connect.Spec{} = spec) do
    action_projections =
      Enum.map(spec.actions, fn action ->
        ActionProjection.new!(%{
          module: Module.concat([integration_module, Actions, Macro.camelize("#{action.name}")]),
          integration_module: integration_module,
          integration_id: spec.id,
          action_id: action.id,
          name: jido_name(action.id),
          label: action.label,
          description: action.description || action.label,
          resource: action.resource,
          verb: action.verb,
          data_classification: action.data_classification,
          input: action.input,
          output: action.output,
          input_schema: action.input_schema,
          output_schema: action.output_schema,
          auth_profile: action.auth_profile,
          auth_profiles: action.auth_profiles,
          policies: action.policies,
          scopes: action.scopes,
          scope_resolver: action.scope_resolver,
          risk: action.risk,
          confirmation: action.confirmation
        })
      end)

    sensor_projections =
      Enum.map(spec.triggers, fn trigger ->
        SensorProjection.new!(%{
          module: Module.concat([integration_module, Sensors, Macro.camelize("#{trigger.name}")]),
          integration_module: integration_module,
          integration_id: spec.id,
          trigger_id: trigger.id,
          name: jido_name(trigger.id),
          label: trigger.label,
          description: trigger.description || trigger.label,
          resource: trigger.resource,
          verb: trigger.verb,
          data_classification: trigger.data_classification,
          kind: trigger.kind,
          config: trigger.config,
          signal: trigger.signal,
          config_schema: trigger.config_schema,
          signal_schema: trigger.signal_schema,
          signal_type: trigger.id,
          signal_source: "/jido/connect/#{spec.id}",
          auth_profile: trigger.auth_profile,
          auth_profiles: trigger.auth_profiles,
          policies: trigger.policies,
          scopes: trigger.scopes,
          scope_resolver: trigger.scope_resolver,
          interval_ms: trigger.interval_ms
        })
      end)

    PluginProjection.new!(%{
      module: Module.concat([integration_module, Plugin]),
      integration_module: integration_module,
      integration_id: spec.id,
      name: jido_name("#{spec.id}"),
      description: "#{spec.name} integration tools.",
      actions: action_projections,
      sensors: sensor_projections
    })
  end

  defp generated_modules_ast(%PluginProjection{} = projection) do
    action_modules = Enum.map(projection.actions, &action_module_ast/1)
    sensor_modules = Enum.map(projection.sensors, &sensor_module_ast/1)
    plugin_module = plugin_module_ast(projection)

    action_modules ++ sensor_modules ++ [plugin_module]
  end

  defp action_module_ast(%ActionProjection{} = projection) do
    quote do
      defmodule unquote(projection.module) do
        @moduledoc false

        use Jido.Action,
          name: unquote(projection.name),
          description: unquote(projection.description),
          schema: unquote(Macro.escape(projection.input_schema)),
          output_schema: unquote(Macro.escape(projection.output_schema))

        @projection unquote(Macro.escape(projection))

        def jido_connect_projection, do: @projection
        def operation_id, do: @projection.action_id

        @impl Jido.Action
        def run(params, context) do
          Jido.Connect.JidoActionRuntime.run(@projection, params, context)
        end
      end
    end
  end

  defp sensor_module_ast(%SensorProjection{} = projection) do
    quote do
      defmodule unquote(projection.module) do
        @moduledoc false

        use Jido.Sensor,
          name: unquote(projection.name),
          description: unquote(projection.description),
          schema: unquote(Macro.escape(projection.config_schema))

        @projection unquote(Macro.escape(projection))

        def jido_connect_projection, do: @projection
        def trigger_id, do: @projection.trigger_id
        def signal_type, do: @projection.signal_type
        def signal_source, do: @projection.signal_source

        @impl Jido.Sensor
        def init(config, context) do
          Jido.Connect.JidoSensorRuntime.init(@projection, config, context)
        end

        @impl Jido.Sensor
        def handle_event(event, state) do
          Jido.Connect.JidoSensorRuntime.handle_event(@projection, event, state)
        end
      end
    end
  end

  defp plugin_module_ast(%PluginProjection{} = projection) do
    action_modules = Enum.map(projection.actions, & &1.module)

    quote do
      defmodule unquote(projection.module) do
        @moduledoc false

        use Jido.Plugin,
          name: unquote(projection.name),
          state_key: unquote(projection.integration_id),
          description: unquote(projection.description),
          actions: unquote(Macro.escape(action_modules)),
          config_schema: Zoi.map()

        @projection unquote(Macro.escape(projection))

        def jido_connect_projection, do: @projection
        defoverridable plugin_spec: 1

        @impl Jido.Plugin
        def plugin_spec(config) do
          %Jido.Plugin.Spec{
            module: __MODULE__,
            name: name(),
            state_key: state_key(),
            description: description(),
            category: category(),
            vsn: vsn(),
            schema: schema(),
            config_schema: config_schema(),
            config: config,
            signal_patterns: signal_patterns(),
            tags: tags(),
            actions:
              @projection
              |> Jido.Connect.JidoPluginRuntime.filtered_actions(config)
              |> Enum.map(& &1.module)
          }
        end

        @impl Jido.Plugin
        def subscriptions(config, context) do
          Jido.Connect.JidoPluginRuntime.subscriptions(@projection, config, context)
        end

        def tool_availability(config \\ %{}) do
          Jido.Connect.JidoPluginRuntime.tool_availability(@projection, config)
        end
      end
    end
  end

  defp jido_name(value) do
    value
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end
end
