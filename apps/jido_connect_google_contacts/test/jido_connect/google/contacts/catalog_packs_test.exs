defmodule Jido.Connect.Google.Contacts.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Contacts

  defmodule FakeContactsClient do
    def create_contact_group(%{name: "Friends"}, "token") do
      {:ok,
       Contacts.Group.new!(%{
         resource_name: "contactGroups/friends",
         name: "Friends"
       })}
    end
  end

  test "readonly pack exposes person and group read tools only" do
    results =
      Catalog.search_tools("contacts",
        modules: [Contacts],
        packs: Contacts.catalog_packs(),
        pack: :google_contacts_readonly
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.contacts.person.list" in ids
    assert "google.contacts.person.get" in ids
    assert "google.contacts.person.search" in ids
    assert "google.contacts.group.list" in ids
    refute "google.contacts.person.create" in ids
    refute "google.contacts.person.delete" in ids
    refute "google.contacts.group.create" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.contacts.person.get",
               modules: [Contacts],
               packs: Contacts.catalog_packs(),
               pack: :google_contacts_readonly
             )

    assert descriptor.tool.id == "google.contacts.person.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.contacts.group.create",
               modules: [Contacts],
               packs: Contacts.catalog_packs(),
               pack: :google_contacts_readonly
             )
  end

  test "manager pack allows contact and group mutations" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.contacts.person.create",
               modules: [Contacts],
               packs: Contacts.catalog_packs(),
               pack: :google_contacts_manager
             )

    assert descriptor.tool.id == "google.contacts.person.create"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.contacts.person.delete",
               modules: [Contacts],
               packs: Contacts.catalog_packs(),
               pack: :google_contacts_manager
             )

    assert descriptor.tool.id == "google.contacts.person.delete"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.contacts.group.update",
               modules: [Contacts],
               packs: Contacts.catalog_packs(),
               pack: :google_contacts_manager
             )

    assert descriptor.tool.id == "google.contacts.group.update"
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok, %{group: %{resource_name: "contactGroups/friends"}}} =
             Catalog.call_tool(
               "google.contacts.group.create",
               %{name: "Friends"},
               modules: [Contacts],
               packs: Contacts.catalog_packs(),
               pack: :google_contacts_manager,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.contacts.group.create",
               %{name: "Friends"},
               modules: [Contacts],
               packs: Contacts.catalog_packs(),
               pack: :google_contacts_readonly,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease do
    scopes = [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/contacts"
    ]

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
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
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_contacts_client: FakeContactsClient},
        scopes: scopes
      })

    {context, lease}
  end
end
