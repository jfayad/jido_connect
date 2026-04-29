defmodule Jido.Connect.CatalogTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Catalog
  alias Jido.Connect.CatalogFixtures

  test "catalog entries derive host-facing metadata from specs" do
    entry = Catalog.entry(CatalogFixtures.Integration)

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
  end

  test "catalog discovery searches and filters configured modules" do
    previous = Application.get_env(:jido_connect, :catalog_modules)
    Application.put_env(:jido_connect, :catalog_modules, [CatalogFixtures.Integration])

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:jido_connect, :catalog_modules)
      else
        Application.put_env(:jido_connect, :catalog_modules, previous)
      end
    end)

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover()
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(query: "item")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(status: :available)
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(auth_kind: "oauth2")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(auth_profile: "user")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(scope: "read")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(package: "jido_connect_catalog")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(tag: "catalog_test")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(capability_kind: "auth")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(capability: "polling")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(tool: "catalog.item.get")
    assert [] = Catalog.discover(query: "missing")
    assert [] = Catalog.discover(status: "unknown_status")

    assert %{
             id: :catalog,
             module: "Jido.Connect.CatalogFixtures.Integration",
             capabilities: [%{provider: :catalog} | _],
             policies: [%{id: :item_access}],
             actions: [%{id: "catalog.item.get"}]
           } = Catalog.discover() |> hd() |> Catalog.to_map()

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
           ] = Catalog.tools()

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] = Catalog.tools(type: :action)

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(resource: :item, verb: :get)

    assert [%Catalog.ToolEntry{id: "catalog.item.created"}] = Catalog.tools(query: "created")
    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] = Catalog.tools(tool: "catalog.item.get")

    assert [
             %Catalog.ToolEntry{id: "catalog.item.get"},
             %Catalog.ToolEntry{id: "catalog.item.created"}
           ] = Catalog.tools(auth_kind: :oauth2)

    assert %{
             provider: :catalog,
             integration_module: "Jido.Connect.CatalogFixtures.Integration",
             id: "catalog.item.get",
             auth_kinds: [:oauth2],
             policies: [:item_access],
             resource: :item,
             verb: :get
           } = Catalog.tools(type: :action) |> hd() |> Catalog.to_map()
  end

  test "catalog discovery skips modules that fail while building entries" do
    previous = Application.get_env(:jido_connect, :catalog_modules)

    Application.put_env(:jido_connect, :catalog_modules, [
      CatalogFixtures.Integration,
      CatalogFixtures.RaisingIntegration,
      CatalogFixtures.InvalidIntegration,
      CatalogFixtures.MissingIntegrationCallback,
      Module.concat(__MODULE__, MissingIntegration)
    ])

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:jido_connect, :catalog_modules)
      else
        Application.put_env(:jido_connect, :catalog_modules, previous)
      end
    end)

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover()

    assert %Catalog.DiscoveryResult{
             entries: [%Catalog.Entry{id: :catalog}],
             diagnostics: diagnostics
           } = Catalog.discover_with_diagnostics()

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
           ] = Catalog.tools()
  end
end
