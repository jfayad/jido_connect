defmodule Jido.Connect.Google.ContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Contacts
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @contacts_dsl_fragments [
    Jido.Connect.Google.Contacts.Actions.Read,
    Jido.Connect.Google.Contacts.Actions.Write
  ]

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

    assert [] = spec.actions
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
      action_modules: [],
      plugin_module: Jido.Connect.Google.Contacts.Plugin,
      plugin_name: "google_contacts"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Contacts, [])
  end

  test "loads Contacts Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@contacts_dsl_fragments)
  end
end
