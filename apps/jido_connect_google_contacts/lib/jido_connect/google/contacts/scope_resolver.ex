defmodule Jido.Connect.Google.Contacts.ScopeResolver do
  @moduledoc """
  Resolves Google Contacts scopes.

  Contact reads use `contacts.readonly` by default. The broader `contacts`
  grant is accepted for reads when hosts already have it and required for
  contact or group mutations.
  """

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"

  @write_actions [
    "google.contacts.person.create",
    "google.contacts.person.update",
    "google.contacts.person.delete",
    "google.contacts.group.create",
    "google.contacts.group.update",
    "google.contacts.group.delete",
    "google.contacts.group.member.modify"
  ]

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @write_actions do
    [@contacts_scope]
  end

  defp required_for_operation(_operation_id, %{scopes: scopes}) when is_list(scopes) do
    cond do
      @contacts_scope in scopes -> [@contacts_scope]
      @contacts_readonly_scope in scopes -> [@contacts_readonly_scope]
      true -> [@contacts_readonly_scope]
    end
  end

  defp required_for_operation(_operation_id, _connection), do: [@contacts_readonly_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
