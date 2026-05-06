defmodule Jido.Connect.Google.Contacts.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Contacts
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Contacts action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(Contacts, [
      action("google.contacts.person.list", :personal_data, :read, :none),
      action("google.contacts.person.get", :personal_data, :read, :none),
      action("google.contacts.person.search", :personal_data, :read, :none),
      action("google.contacts.person.create", :personal_data, :write, :required_for_ai),
      action("google.contacts.person.update", :personal_data, :write, :required_for_ai),
      action("google.contacts.person.delete", :personal_data, :destructive, :always)
    ])
  end

  defp action(id, classification, risk, confirmation) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation
    }
  end
end
