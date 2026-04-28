defmodule Jido.Connect.RuntimeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Jido.{ActionProjection, PluginProjection, SensorProjection, ToolAvailability}

  defmodule ActionHandler do
    def run(%{repo: repo}, _context), do: {:ok, %{repo: repo}}
  end

  defmodule RawErrorHandler do
    def run(_input, _context), do: {:error, :provider_returned_atom}
  end

  defmodule InvalidResultHandler do
    def run(_input, _context), do: :ok
  end

  defmodule PollHandler do
    def poll(%{repo: repo}, %{checkpoint: checkpoint}) do
      {:ok, %{signals: [%{repo: repo}], checkpoint: checkpoint || "next"}}
    end
  end

  defmodule BadPollHandler do
    def poll(_config, _context), do: {:ok, %{signals: [%{}], checkpoint: nil}}
  end

  defmodule Integration do
    def integration, do: Jido.Connect.RuntimeTest.spec()
  end

  defmodule InvalidIntegration do
    def integration, do: :not_a_spec
  end

  test "top-level API accepts provider modules or compiled specs" do
    spec = spec()
    {context, lease} = context_and_lease()

    assert {:ok, ^spec} = Connect.spec(spec)
    assert {:ok, ^spec} = Connect.spec(Integration)
    assert {:ok, [%{id: "demo.repo.show"}]} = Connect.actions(Integration)
    assert {:ok, [%{id: "demo.repo.changed"}]} = Connect.triggers(Integration)
    assert {:ok, [%{id: :user}]} = Connect.auth_profiles(Integration)

    assert {:ok, %{id: "demo.repo.show"}} = Connect.action(Integration, "demo.repo.show")
    assert {:ok, %{id: "demo.repo.changed"}} = Connect.trigger(Integration, "demo.repo.changed")

    assert {:ok, %{repo: "org/repo"}} =
             Connect.invoke(
               Integration,
               "demo.repo.show",
               %{repo: "org/repo"},
               %{context: context, credential_lease: lease}
             )

    assert {:ok, %{signals: [%{repo: "org/repo"}], checkpoint: "next"}} =
             Connect.poll(
               Integration,
               "demo.repo.changed",
               %{repo: "org/repo"},
               %{context: context, credential_lease: lease}
             )

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_integration}} =
             Connect.spec(Module.concat(__MODULE__, MissingIntegration))

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_integration}} =
             Connect.spec(InvalidIntegration)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_action_id}} =
             Connect.action(Integration, :not_a_string)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_trigger_id}} =
             Connect.trigger(Integration, :not_a_string)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_action_id}} =
             Connect.invoke(Integration, :not_a_string, %{})

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_invocation}} =
             Connect.invoke(Integration, "demo.repo.show", [])

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_trigger_id}} =
             Connect.poll(Integration, :not_a_string, %{})

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_poll}} =
             Connect.poll(Integration, "demo.repo.changed", [])
  end

  test "lookup, invoke, poll, and auth failures return structured errors" do
    spec = spec()
    {context, lease} = context_and_lease()

    assert {:ok, %{id: "demo.repo.show"}} = Connect.action(spec, "demo.repo.show")
    assert {:ok, %{id: "demo.repo.changed"}} = Connect.trigger(spec, "demo.repo.changed")

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_action}} =
             Connect.action(spec, "missing")

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_trigger}} =
             Connect.trigger(spec, "missing")

    assert {:ok, %{repo: "org/repo"}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{signals: [%{repo: "org/repo"}], checkpoint: "cursor"}} =
             Connect.poll(spec, "demo.repo.changed", %{repo: "org/repo"},
               context: context,
               credential_lease: lease,
               checkpoint: "cursor"
             )

    assert {:ok, %{repo: "org/repo"}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: Map.from_struct(context),
               credential_lease: Map.from_struct(lease)
             )

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_required}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"}, context: context)

    disconnected = %{context | connection: %{context.connection | status: :needs_credentials}}

    assert {:error, %Connect.Error.AuthError{reason: :connection_required}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: disconnected,
               credential_lease: lease
             )

    mismatched_lease = %{lease | connection_id: "other"}

    assert {:error, %Connect.Error.AuthError{reason: :credential_connection_mismatch}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: mismatched_lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :handler,
              details: %{operation_id: "demo.repo.show", error: "provider_returned_atom"}
            }} =
             spec(%{action: %{handler: RawErrorHandler}})
             |> Connect.invoke("demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :handler,
              details: %{operation_id: "demo.repo.show", returned: "ok"}
            }} =
             spec(%{action: %{handler: InvalidResultHandler}})
             |> Connect.invoke("demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    missing_scopes = %{context | connection: %{context.connection | scopes: []}}

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["repo"]}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: missing_scopes,
               credential_lease: lease
             )

    reduced_lease = %{lease | scopes: []}

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["repo"]}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: reduced_lease
             )

    expired_lease = %{lease | expires_at: DateTime.add(DateTime.utc_now(), -60, :second)}

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_expired}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: expired_lease
             )

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_expired}} =
             Connect.poll(spec, "demo.repo.changed", %{repo: "org/repo"},
               context: context,
               credential_lease: expired_lease
             )

    unsupported_profile = %{
      context
      | connection: %{context.connection | profile: :installation}
    }

    assert {:error, %Connect.Error.AuthError{reason: :unsupported_auth_profile}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: unsupported_profile,
               credential_lease: lease
             )

    mismatched_binding = %{lease | provider: :other}

    assert {:error,
            %Connect.Error.AuthError{
              reason: :credential_connection_mismatch,
              details: %{field: :provider, expected: :demo, actual: :other}
            }} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: mismatched_binding
             )

    assert {:error, %Connect.Error.ValidationError{reason: :signal}} =
             Connect.poll(bad_signal_spec(), "demo.repo.changed", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )
  end

  test "Jido runtimes adapt projections without provider logic" do
    {context, lease} = context_and_lease()
    projection = action_projection()

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               context: context,
               credential_lease: lease
             })

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               tenant_id: context.tenant_id,
               actor: context.actor,
               connection: context.connection,
               credential_lease: lease
             })

    selector =
      Connect.ConnectionSelector.per_actor(:demo, "tenant_1", "user_1",
        profile: :user,
        required_scopes: ["repo"]
      )
      |> elem(1)

    tenant_context = %{context | connection: nil, connection_selector: selector}

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: tenant_context,
               connection_resolver: fn ^selector, ^projection, _agent_context ->
                 context.connection
               end,
               credential_lease: lease
             })

    mismatched_selector =
      Connect.ConnectionSelector.tenant_default(:demo, "tenant_1", profile: :user)
      |> elem(1)

    mismatched_context = %{context | connection: nil, connection_selector: mismatched_selector}

    assert {:error, %Connect.Error.AuthError{reason: :connection_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: mismatched_context,
               connection_resolver: fn ^mismatched_selector, ^projection, _agent_context ->
                 context.connection
               end,
               credential_lease: lease
             })

    assert {:error, %Connect.Error.AuthError{reason: :context_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               credential_lease: lease
             })

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: context
             })

    sensor = sensor_projection()

    assert {:ok, state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(sensor, %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, _state, [{:emit, signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, state)

    assert signal.type == "demo.repo.changed"
    assert signal.source == "/jido/connect/demo"
    assert signal.data.repo == "org/repo"

    assert {:ok, selector_state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(sensor, %{repo: "org/repo"}, %{
               integration_context: tenant_context,
               connection_resolver: fn ^selector, ^sensor, _runtime_context ->
                 context.connection
               end,
               credential_lease: lease
             })

    assert {:ok, _state, [{:emit, _selector_signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, selector_state)

    webhook = %{sensor | kind: :webhook}
    assert {:ok, %{projection: ^webhook}} = Connect.JidoSensorRuntime.init(webhook, %{}, %{})
    assert {:ok, :state} = Connect.JidoSensorRuntime.handle_event(webhook, :anything, :state)
  end

  test "plugin runtime filters subscriptions and availability" do
    {context, _lease} = context_and_lease()
    projection = plugin_projection()

    assert [action] = Connect.JidoPluginRuntime.filtered_actions(projection, %{})
    assert action.action_id == "demo.repo.show"

    assert [] = Connect.JidoPluginRuntime.filtered_actions(projection, %{allowed_actions: []})

    assert [sensor] = Connect.JidoPluginRuntime.filtered_sensors(projection, %{})
    assert sensor.trigger_id == "demo.repo.changed"

    assert [{Connect.RuntimeTest.Integration.Sensors.RepoChanged, %{repo: "org/repo"}}] =
             Connect.JidoPluginRuntime.subscriptions(
               projection,
               %{trigger_config: %{repo: "org/repo"}},
               %{}
             )

    assert [
             %ToolAvailability{state: :available, connection_id: "conn_1"},
             %ToolAvailability{state: :available, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection: context.connection
             })

    assert [
             %ToolAvailability{state: :connection_required, connection_id: "conn_1"},
             %ToolAvailability{state: :connection_required, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_id: "conn_1"
             })

    assert [
             %ToolAvailability{state: :available, connection_id: "conn_1"},
             %ToolAvailability{state: :available, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_id: "conn_1",
               connection_resolver: fn "conn_1" -> context.connection end
             })

    assert [
             %ToolAvailability{state: :missing_scopes, connection_id: "conn_1"},
             %ToolAvailability{state: :missing_scopes, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_id: "conn_1",
               connection_resolver: fn _connection_id ->
                 %{context.connection | scopes: []}
               end
             })

    tenant_selector =
      Connect.ConnectionSelector.per_actor(:demo, "tenant_1", "user_1", profile: :user)
      |> elem(1)

    assert [
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^tenant_selector
             },
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^tenant_selector
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: tenant_selector
             })

    assert [
             %ToolAvailability{state: :available, connection_id: "conn_1"},
             %ToolAvailability{state: :available, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: tenant_selector,
               connection_resolver: fn ^tenant_selector, _operation, _config ->
                 context.connection
               end
             })

    mismatched_selector =
      Connect.ConnectionSelector.tenant_default(:demo, "tenant_1", profile: :user)
      |> elem(1)

    assert [
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^mismatched_selector
             },
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^mismatched_selector
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: mismatched_selector,
               connection_resolver: fn ^mismatched_selector, _operation, _config ->
                 context.connection
               end
             })

    assert [
             %ToolAvailability{
               state: :connection_required,
               connection_selector: {:provider, :demo}
             },
             %ToolAvailability{
               state: :connection_required,
               connection_selector: {:provider, :demo}
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: {:provider, :demo}
             })
  end

  test "projection structs expose Zoi schemas and safe constructors" do
    action = action_projection()
    sensor = sensor_projection()
    plugin = plugin_projection()

    assert ActionProjection.schema()
    assert SensorProjection.schema()
    assert PluginProjection.schema()
    assert ToolAvailability.schema()

    assert {:ok, ^action} = ActionProjection.new(Map.from_struct(action))
    assert {:ok, ^sensor} = SensorProjection.new(Map.from_struct(sensor))
    assert {:ok, ^plugin} = PluginProjection.new(Map.from_struct(plugin))

    availability = ToolAvailability.new!(%{tool: "demo.repo.show", state: :available})
    assert {:ok, ^availability} = ToolAvailability.new(Map.from_struct(availability))
  end

  test "spec validation errors use the package taxonomy" do
    assert_raise Connect.Error.ValidationError, ~r/Unknown auth profile/, fn ->
      spec(%{action: %{auth_profile: :missing}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Mutation action/, fn ->
      spec(%{action: %{mutation?: true, confirmation: :none}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Poll trigger/, fn ->
      spec(%{trigger: %{checkpoint: nil}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Unknown auth profile/, fn ->
      build_spec(triggers: [Map.merge(trigger_attrs(), %{auth_profile: :missing})])
    end

    assert_raise Connect.Error.ValidationError, ~r/Duplicate action ids/, fn ->
      base = action_attrs()
      build_spec(actions: [base, Map.put(base, :name, :duplicate)])
    end

    assert_raise Connect.Error.ValidationError, ~r/Unsupported integration field type/, fn ->
      Connect.zoi_schema_from_fields([Connect.Field.new!(%{name: :bad, type: :unknown})])
    end
  end

  test "field schemas support defaults, enums, optional fields, and nested lists" do
    schema =
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{
          name: :state,
          type: :string,
          enum: ["open", "closed"],
          required?: true
        }),
        Connect.Field.new!(%{name: :limit, type: :integer, default: 100}),
        Connect.Field.new!(%{name: :active, type: :boolean}),
        Connect.Field.new!(%{name: :metadata, type: :map}),
        Connect.Field.new!(%{name: :labels, type: {:array, :string}, default: []})
      ])

    assert {:ok,
            %{
              state: "open",
              limit: 50,
              active: true,
              metadata: %{source: "test"},
              labels: ["bug"]
            }} =
             Zoi.parse(schema, %{
               state: "open",
               limit: 50,
               active: true,
               metadata: %{source: "test"},
               labels: ["bug"]
             })
  end

  def spec(overrides \\ %{}) do
    build_spec(
      auth_profiles: [auth_profile()],
      actions: [Map.merge(action_attrs(), Map.get(overrides, :action, %{}))],
      triggers: [Map.merge(trigger_attrs(), Map.get(overrides, :trigger, %{}))]
    )
  end

  defp build_spec(attrs) do
    Connect.Spec.new!(%{
      id: :demo,
      name: "Demo",
      auth_profiles: Keyword.get(attrs, :auth_profiles, [auth_profile()]),
      actions:
        Enum.map(Keyword.get(attrs, :actions, [action_attrs()]), &Connect.ActionSpec.new!/1),
      triggers:
        Enum.map(Keyword.get(attrs, :triggers, [trigger_attrs()]), &Connect.TriggerSpec.new!/1)
    })
  end

  defp bad_signal_spec do
    build_spec(
      actions: [action_attrs()],
      triggers: [Map.merge(trigger_attrs(), %{handler: BadPollHandler})]
    )
  end

  defp auth_profile do
    Connect.AuthProfile.new!(%{
      id: :user,
      kind: :oauth2,
      owner: :user,
      subject: :user,
      label: "User"
    })
  end

  defp action_attrs do
    %{
      id: "demo.repo.show",
      name: :show_repo,
      label: "Show repo",
      description: "Show repo",
      auth_profile: :user,
      handler: ActionHandler,
      input: [field(:repo)],
      output: [field(:repo)],
      input_schema: Zoi.object(%{repo: Zoi.string()}),
      output_schema: Zoi.object(%{repo: Zoi.string()}),
      scopes: ["repo"]
    }
  end

  defp trigger_attrs do
    %{
      id: "demo.repo.changed",
      name: :repo_changed,
      kind: :poll,
      label: "Repo changed",
      description: "Repo changed",
      auth_profile: :user,
      handler: PollHandler,
      config: [field(:repo)],
      signal: [field(:repo)],
      config_schema: Zoi.object(%{repo: Zoi.string()}),
      signal_schema: Zoi.object(%{repo: Zoi.string()}),
      scopes: ["repo"],
      interval_ms: 1_000,
      checkpoint: :updated_at,
      dedupe: %{field: :repo}
    }
  end

  defp field(name) do
    Connect.Field.new!(%{name: name, type: :string, required?: true})
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :demo,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["repo"]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        fields: %{}
      })

    {context, lease}
  end

  defp action_projection do
    ActionProjection.new!(%{
      module: Connect.RuntimeTest.Integration.Actions.ShowRepo,
      integration_module: Integration,
      integration_id: :demo,
      action_id: "demo.repo.show",
      name: "demo_repo_show",
      label: "Show repo",
      description: "Show repo",
      input: [field(:repo)],
      output: [field(:repo)],
      input_schema: Zoi.object(%{repo: Zoi.string()}),
      output_schema: Zoi.object(%{repo: Zoi.string()}),
      auth_profile: :user,
      scopes: ["repo"],
      risk: :read,
      confirmation: :none
    })
  end

  defp sensor_projection do
    SensorProjection.new!(%{
      module: Connect.RuntimeTest.Integration.Sensors.RepoChanged,
      integration_module: Integration,
      integration_id: :demo,
      trigger_id: "demo.repo.changed",
      name: "demo_repo_changed",
      label: "Repo changed",
      description: "Repo changed",
      kind: :poll,
      config: [field(:repo)],
      signal: [field(:repo)],
      config_schema: Zoi.object(%{repo: Zoi.string()}),
      signal_schema: Zoi.object(%{repo: Zoi.string()}),
      signal_type: "demo.repo.changed",
      signal_source: "/jido/connect/demo",
      auth_profile: :user,
      scopes: ["repo"],
      interval_ms: 1_000
    })
  end

  defp plugin_projection do
    PluginProjection.new!(%{
      module: Connect.RuntimeTest.Integration.Plugin,
      integration_module: Integration,
      integration_id: :demo,
      name: "demo",
      description: "Demo integration tools.",
      actions: [action_projection()],
      sensors: [sensor_projection()]
    })
  end
end
