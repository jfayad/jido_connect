defmodule Jido.Connect.Google.TestSupport.ConnectorContracts do
  @moduledoc false

  import ExUnit.Assertions

  @doc "Asserts the generated Jido action, sensor, manifest, and plugin surface."
  def assert_generated_surface(provider, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    action_modules = Keyword.fetch!(opts, :action_modules)
    sensor_specs = Keyword.get(opts, :sensor_specs, [])
    sensor_modules = Enum.map(sensor_specs, &Map.fetch!(&1, :module))
    plugin_module = Keyword.fetch!(opts, :plugin_module)
    plugin_name = Keyword.fetch!(opts, :plugin_name)

    assert Application.get_env(otp_app, :jido_connect_providers) == [provider]
    assert provider.jido_action_modules() == action_modules
    assert provider.jido_sensor_modules() == sensor_modules
    assert provider.jido_plugin_module() == plugin_module

    integration = provider.integration()
    action_ids = integration.actions |> Enum.map(& &1.id) |> MapSet.new()
    integration_id = integration.id
    integration_package = integration.package

    assert %Jido.Connect.Catalog.Manifest{
             id: ^integration_id,
             package: ^integration_package,
             generated_modules: %{
               actions: ^action_modules,
               sensors: ^sensor_modules,
               plugin: ^plugin_module
             }
           } = provider.jido_connect_manifest()

    for module <- action_modules do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)

      projection = module.jido_connect_projection()
      tool = module.to_tool()

      assert projection.module == module
      assert projection.action_id in action_ids
      assert module.operation_id() == projection.action_id
      assert module.name() == projection.name
      assert tool.name == projection.name
    end

    for %{module: module, name: name, trigger_id: trigger_id, signal_type: signal_type} <-
          sensor_specs do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :handle_event, 2)
      assert module.name() == name
      assert module.trigger_id() == trigger_id
      assert module.signal_type() == signal_type
    end

    assert %Jido.Plugin.Spec{
             name: ^plugin_name,
             module: ^plugin_module,
             actions: ^action_modules
           } = plugin_module.plugin_spec()
  end

  @doc "Asserts product pack delegate functions and catalog ordering."
  def assert_catalog_pack_delegates(provider, expected_delegates) do
    expected_ids =
      for {function, expected_id} <- expected_delegates do
        assert %{id: ^expected_id} = apply(provider, function, [])
        expected_id
      end

    assert Enum.map(provider.catalog_packs(), & &1.id) == expected_ids
  end

  @doc "Asserts a product DSL fragment compiles as a Jido.Connect Spark fragment."
  def assert_spark_fragments(fragments) do
    for fragment <- fragments do
      assert {:module, ^fragment} = Code.ensure_loaded(fragment)
      assert fragment.extensions() == [Jido.Connect.Dsl.Extension]
      assert fragment.opts() == [of: Jido.Connect]
      assert %{extensions: [Jido.Connect.Dsl.Extension]} = fragment.persisted()
      assert is_map(fragment.spark_dsl_config())

      assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
               fragment.validate_sections()
    end
  end

  @doc "Asserts the minimum scope resolver contract without replacing product-specific cases."
  def assert_scope_resolver_shape(resolver, expected_default_scopes) do
    expected_default_scopes = List.wrap(expected_default_scopes)

    assert function_exported?(resolver, :required_scopes, 3)
    assert resolver.required_scopes(%{}, %{}, %{}) == expected_default_scopes
    assert Enum.all?(expected_default_scopes, &is_binary/1)
  end

  @doc "Asserts Zoi-backed normalized structs expose required defaults and schemas."
  def assert_struct_defaults(module, attrs, expected_defaults) do
    assert {:module, ^module} = Code.ensure_loaded(module)
    assert function_exported?(module, :new, 1)
    assert function_exported?(module, :new!, 1)
    assert function_exported?(module, :schema, 0)

    struct = module.new!(attrs)
    assert %{__struct__: ^module} = struct

    for {field, expected_value} <- expected_defaults do
      assert Map.fetch!(struct, field) == expected_value
    end

    assert module.schema()
    struct
  end
end
