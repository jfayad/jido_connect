defmodule Jido.Connect.CatalogTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Catalog
  alias Jido.Connect.CatalogFixtures

  test "catalog entries derive host-facing metadata from specs" do
    entry = Catalog.entry(CatalogFixtures.Integration)
    manifest = Catalog.manifest(CatalogFixtures.Integration)

    assert %Catalog.Entry{
             id: :catalog,
             package: :jido_connect_catalog,
             tags: [:catalog_test],
             policies: [%{id: :item_access}]
           } = entry

    assert Enum.any?(entry.capabilities, &(&1.feature == :oauth2))
    assert Enum.any?(entry.capabilities, &(&1.feature == :generated_jido_actions))
    assert Enum.any?(entry.capabilities, &(&1.feature == :polling))
    assert [%Catalog.AuthProfileSummary{id: :user, kind: :oauth2}] = entry.auth_profiles

    assert [%Catalog.Tool{id: "catalog.item.get", type: :action, resource: :item, verb: :get}] =
             entry.actions

    assert [
             %Catalog.Tool{
               id: "catalog.item.created",
               type: :trigger,
               trigger_kind: :poll,
               resource: :item,
               verb: :watch
             }
           ] =
             entry.triggers

    assert [%Catalog.Entry{id: :catalog}] = Catalog.entries([CatalogFixtures.Integration])

    assert %Catalog.Manifest{
             id: :catalog,
             package: :jido_connect_catalog,
             generated_modules: %{actions: [], sensors: [], plugin: nil}
           } = manifest
  end

  test "catalog discovery searches and filters configured modules" do
    modules = [CatalogFixtures.Integration]

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules)
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules, query: "item")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules, status: :available)

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, auth_kind: "oauth2")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, auth_profile: "user")

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules, scope: "read")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, package: "jido_connect_catalog")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, tag: "catalog_test")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, capability_kind: "auth")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, capability: "polling")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, tool: "catalog.item.get")

    assert [] = Catalog.discover(modules: modules, query: "missing")
    assert [] = Catalog.discover(modules: modules, status: "unknown_status")

    assert %{
             id: :catalog,
             module: "Jido.Connect.CatalogFixtures.Integration",
             capabilities: [%{provider: :catalog} | _],
             policies: [%{id: :item_access}],
             actions: [%{id: "catalog.item.get"}]
           } = Catalog.discover(modules: modules) |> hd() |> Catalog.to_map()

    assert [
             %Catalog.ToolEntry{
               provider: :catalog,
               type: :action,
               id: "catalog.item.get",
               auth_kinds: [:oauth2]
             },
             %Catalog.ToolEntry{
               provider: :catalog,
               type: :trigger,
               id: "catalog.item.created"
             }
           ] = Catalog.tools(modules: modules)

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(modules: modules, type: :action)

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(modules: modules, resource: :item, verb: :get)

    assert [%Catalog.ToolEntry{id: "catalog.item.created"}] =
             Catalog.tools(modules: modules, query: "created")

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(modules: modules, tool: "catalog.item.get")

    assert [
             %Catalog.ToolEntry{id: "catalog.item.get"},
             %Catalog.ToolEntry{id: "catalog.item.created"}
           ] = Catalog.tools(modules: modules, auth_kind: :oauth2)

    assert %{
             provider: :catalog,
             integration_module: "Jido.Connect.CatalogFixtures.Integration",
             id: "catalog.item.get",
             auth_kinds: [:oauth2],
             policies: [:item_access],
             resource: :item,
             verb: :get
           } = Catalog.tools(modules: modules, type: :action) |> hd() |> Catalog.to_map()
  end

  test "catalog discovery includes app-registered provider modules" do
    previous_modules = Application.get_env(:jido_connect, :catalog_modules)
    previous_providers = Application.get_env(:jido_connect, :jido_connect_providers)

    Application.put_env(:jido_connect, :catalog_modules, [])
    Application.put_env(:jido_connect, :jido_connect_providers, [CatalogFixtures.Integration])

    on_exit(fn ->
      restore_env(:catalog_modules, previous_modules)
      restore_env(:jido_connect_providers, previous_providers)
    end)

    assert CatalogFixtures.Integration in Catalog.configured_modules()
    assert CatalogFixtures.Integration in Catalog.registered_modules()
    assert Enum.any?(Catalog.discover(), &(&1.id == :catalog))
  end

  test "catalog discovery skips modules that fail while building entries" do
    modules = [
      CatalogFixtures.Integration,
      CatalogFixtures.RaisingIntegration,
      CatalogFixtures.InvalidIntegration,
      CatalogFixtures.MissingIntegrationCallback,
      Module.concat(__MODULE__, MissingIntegration)
    ]

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules)

    assert %Catalog.DiscoveryResult{
             entries: [%Catalog.Entry{id: :catalog}],
             diagnostics: diagnostics
           } = Catalog.discover_with_diagnostics(modules: modules)

    assert Enum.map(diagnostics, & &1.reason) == [
             :entry_failed,
             :entry_failed,
             :missing_integration_callback,
             :module_not_loaded
           ]

    assert Enum.any?(diagnostics, &(&1.module == CatalogFixtures.RaisingIntegration))
    assert Enum.any?(diagnostics, &(&1.module == CatalogFixtures.InvalidIntegration))
    assert Enum.any?(diagnostics, &(&1.module == CatalogFixtures.MissingIntegrationCallback))
    assert Enum.any?(diagnostics, &(&1.module == Module.concat(__MODULE__, MissingIntegration)))

    assert [
             %Catalog.ToolEntry{id: "catalog.item.get"},
             %Catalog.ToolEntry{id: "catalog.item.created"}
           ] = Catalog.tools(modules: [CatalogFixtures.Integration])
  end

  defp restore_env(key, nil), do: Application.delete_env(:jido_connect, key)
  defp restore_env(key, value), do: Application.put_env(:jido_connect, key, value)
end
