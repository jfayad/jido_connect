defmodule Jido.Connect.Dsl.Transformers.BuildSpec do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias Jido.Connect
  alias Jido.Connect.Dsl
  alias Jido.Connect.Jido.{ActionProjection, PluginProjection, SensorProjection}
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    with {:ok, integration_attrs} <- integration_attrs(dsl_state),
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

  defp integration_attrs(dsl_state) do
    id = Transformer.get_option(dsl_state, [:integration], :id)
    name = Transformer.get_option(dsl_state, [:integration], :name)

    if id && name do
      {:ok,
       %{
         id: id,
         name: name,
         category: Transformer.get_option(dsl_state, [:integration], :category),
         docs: Transformer.get_option(dsl_state, [:integration], :docs, []),
         metadata: Transformer.get_option(dsl_state, [:integration], :metadata, %{})
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

    actions =
      dsl_state
      |> Transformer.get_entities([:actions])
      |> Enum.map(&action_spec!(&1, integration_attrs.id))

    triggers =
      dsl_state
      |> Transformer.get_entities([:triggers])
      |> Enum.map(&trigger_spec!(&1, integration_attrs.id))

    spec =
      integration_attrs
      |> Map.put(:auth_profiles, auth_profiles)
      |> Map.put(:actions, actions)
      |> Map.put(:triggers, triggers)
      |> Connect.Spec.new!()

    {:ok, spec}
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp auth_profile!(%Dsl.AuthProfile{} = profile) do
    Connect.AuthProfile.new!(Map.from_struct(profile))
  end

  defp action_spec!(%Dsl.Action{} = action, integration_id) do
    input = fields(action.input)
    output = fields(action.output)

    Connect.ActionSpec.new!(%{
      id: action.id || "#{integration_id}.#{action.name}",
      name: action.name,
      label: action.label || humanize(action.name),
      description: action.description,
      auth_profile: action.auth || default_auth_profile(),
      handler: action.handler,
      input: input,
      output: output,
      input_schema: Connect.zoi_schema_from_fields(input),
      output_schema: Connect.zoi_schema_from_fields(output),
      scopes: action.scopes,
      mutation?: action.mutation?,
      risk: action.risk,
      confirmation: action.confirmation,
      metadata: action.metadata
    })
  end

  defp trigger_spec!(%Dsl.Trigger{} = trigger, integration_id) do
    config = fields(trigger.config)
    signal = fields(trigger.signal)

    Connect.TriggerSpec.new!(%{
      id: trigger.id || "#{integration_id}.#{trigger.name}",
      name: trigger.name,
      kind: trigger.kind,
      label: trigger.label || humanize(trigger.name),
      description: trigger.description,
      auth_profile: trigger.auth || default_auth_profile(),
      handler: trigger.handler,
      config: config,
      signal: signal,
      config_schema: Connect.zoi_schema_from_fields(config),
      signal_schema: Connect.zoi_schema_from_fields(signal),
      scopes: trigger.scopes,
      verification: trigger.verification || %{kind: :none},
      dedupe: trigger.dedupe,
      checkpoint: trigger.checkpoint,
      interval_ms: trigger.interval_ms,
      metadata: trigger.metadata
    })
  end

  defp default_auth_profile, do: :user

  defp fields(%Dsl.FieldGroup{fields: fields}), do: fields || []
  defp fields(nil), do: []
  defp fields(fields) when is_list(fields), do: fields

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
        %ActionProjection{
          module: Module.concat([integration_module, Actions, Macro.camelize("#{action.name}")]),
          integration_module: integration_module,
          integration_id: spec.id,
          action_id: action.id,
          name: jido_name(action.id),
          description: action.description || action.label,
          input_schema: action.input_schema,
          output_schema: action.output_schema,
          auth_profile: action.auth_profile,
          scopes: action.scopes,
          risk: action.risk,
          confirmation: action.confirmation
        }
      end)

    sensor_projections =
      Enum.map(spec.triggers, fn trigger ->
        %SensorProjection{
          module: Module.concat([integration_module, Sensors, Macro.camelize("#{trigger.name}")]),
          integration_module: integration_module,
          integration_id: spec.id,
          trigger_id: trigger.id,
          name: jido_name(trigger.id),
          description: trigger.description || trigger.label,
          kind: trigger.kind,
          config_schema: trigger.config_schema,
          signal_schema: trigger.signal_schema,
          signal_type: trigger.id,
          signal_source: "/jido/connect/#{spec.id}",
          auth_profile: trigger.auth_profile,
          scopes: trigger.scopes,
          interval_ms: trigger.interval_ms
        }
      end)

    %PluginProjection{
      module: Module.concat([integration_module, Plugin]),
      integration_module: integration_module,
      integration_id: spec.id,
      name: jido_name("#{spec.id}"),
      description: "#{spec.name} integration tools.",
      actions: action_projections,
      sensors: sensor_projections
    }
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
