defmodule Jido.Connect.Google.Contacts.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Contacts.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"

  test "declares Contacts read and mutation scope matrix" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, @contacts_readonly_scope)

    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "missing contact read grant falls back to readonly Contacts scope",
        operation: "google.contacts.person.list",
        granted: [],
        expected: @contacts_readonly_scope
      },
      %{
        label: "broad Contacts grant can satisfy person reads",
        operation: "google.contacts.person.get",
        granted: [@contacts_scope],
        expected: @contacts_scope
      },
      %{
        label: "contact search uses readonly Contacts scope",
        operation: "google.contacts.person.search",
        granted: [@contacts_readonly_scope],
        expected: @contacts_readonly_scope
      },
      %{
        label: "contact mutation requires Contacts write scope",
        operation: "google.contacts.person.update",
        granted: [@contacts_readonly_scope],
        expected: @contacts_scope
      },
      %{
        label: "group mutation requires Contacts write scope",
        operation: "google.contacts.group.member.modify",
        granted: [@contacts_readonly_scope],
        expected: @contacts_scope
      }
    ])
  end
end
