defmodule Jido.Connect.Google.ContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Contacts
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @contacts_action_modules [
    Jido.Connect.Google.Contacts.Actions.ListPeople,
    Jido.Connect.Google.Contacts.Actions.GetPerson,
    Jido.Connect.Google.Contacts.Actions.SearchPeople,
    Jido.Connect.Google.Contacts.Actions.CreateContact,
    Jido.Connect.Google.Contacts.Actions.UpdateContact,
    Jido.Connect.Google.Contacts.Actions.DeleteContact
  ]

  @contacts_dsl_fragments [
    Jido.Connect.Google.Contacts.Actions.Read,
    Jido.Connect.Google.Contacts.Actions.Write
  ]

  defmodule FakeContactsClient do
    def list_people(
          %{resource_name: "people/me", page_size: 100, request_sync_token: false},
          "token"
        ) do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             display_name: "Ada Lovelace",
             email_addresses: [%{value: "ada@example.com"}]
           })
         ],
         next_page_token: "contacts-next",
         total_items: 1
       }}
    end

    def get_person(%{resource_name: "people/me"}, "token") do
      {:ok,
       Contacts.Person.new!(%{
         resource_name: "people/me",
         display_name: "Ada Lovelace"
       })}
    end

    def search_people(%{query: "Ada", page_size: 10}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             display_name: "Ada Lovelace"
           })
         ]
       }}
    end

    def create_contact(
          %{
            given_name: "Ada",
            family_name: "Lovelace",
            email_addresses: [%{value: "ada@example.com"}],
            phone_numbers: [%{value: "+1 555 0100"}],
            organizations: [%{name: "Analytical Engines"}]
          },
          "token"
        ) do
      {:ok,
       Contacts.Person.new!(%{
         resource_name: "people/c123",
         display_name: "Ada Lovelace"
       })}
    end

    def update_contact(
          %{
            resource_name: "people/c123",
            etag: "etag123",
            given_name: "Ada"
          },
          "token"
        ) do
      {:ok,
       Contacts.Person.new!(%{
         resource_name: "people/c123",
         etag: "etag456",
         given_name: "Ada"
       })}
    end

    def delete_contact(%{resource_name: "people/c123"}, "token") do
      {:ok, %{resource_name: "people/c123", deleted?: true}}
    end
  end

  test "declares Google Contacts provider metadata" do
    spec = Contacts.integration()

    assert spec.id == :google_contacts
    assert spec.package == :jido_connect_google_contacts
    assert spec.name == "Google Contacts"
    assert spec.tags == [:google, :workspace, :contacts, :productivity]
    assert spec.status == :experimental

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Contacts,
      id_prefix: "google.contacts.",
      pack_id_prefix: "google_contacts_",
      module_namespace: Jido.Connect.Google.Contacts
    )

    assert Enum.map(spec.actions, & &1.id) == [
             "google.contacts.person.list",
             "google.contacts.person.get",
             "google.contacts.person.search",
             "google.contacts.person.create",
             "google.contacts.person.update",
             "google.contacts.person.delete"
           ]

    assert [] = spec.triggers

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert "https://www.googleapis.com/auth/contacts.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/contacts" in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Contacts,
      otp_app: :jido_connect_google_contacts,
      action_modules: @contacts_action_modules,
      plugin_module: Jido.Connect.Google.Contacts.Plugin,
      plugin_name: "google_contacts"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Contacts, [])
  end

  test "loads Contacts Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@contacts_dsl_fragments)
  end

  test "invokes Contacts person read and search actions through the runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{people: [%{display_name: "Ada Lovelace"}], next_page_token: "contacts-next"}} =
             Connect.invoke(Contacts, "google.contacts.person.list", %{},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{person: %{resource_name: "people/me", display_name: "Ada Lovelace"}}} =
             Connect.invoke(Contacts, "google.contacts.person.get", %{resource_name: "people/me"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{people: [%{resource_name: "people/c123"}]}} =
             Connect.invoke(Contacts, "google.contacts.person.search", %{query: "Ada"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes Contacts contact mutation actions through the runtime" do
    {context, lease} = context_and_lease(scopes: ["https://www.googleapis.com/auth/contacts"])

    assert {:ok, %{person: %{resource_name: "people/c123", display_name: "Ada Lovelace"}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.create",
               %{
                 given_name: "Ada",
                 family_name: "Lovelace",
                 email_addresses: [%{value: "ada@example.com"}],
                 phone_numbers: [%{value: "+1 555 0100"}],
                 organizations: [%{name: "Analytical Engines"}]
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{person: %{resource_name: "people/c123", etag: "etag456"}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.update",
               %{resource_name: "people/c123", etag: "etag123", given_name: "Ada"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{resource_name: "people/c123", deleted?: true}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.delete",
               %{resource_name: "people/c123"},
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/contacts.readonly"
      ] ++ Keyword.get(opts, :scopes, [])

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
