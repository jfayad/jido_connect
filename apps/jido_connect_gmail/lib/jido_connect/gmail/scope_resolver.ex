defmodule Jido.Connect.Gmail.ScopeResolver do
  @moduledoc """
  Resolves Gmail scopes.

  Metadata reads prefer `gmail.metadata`, while accepting broader read or
  modify grants that hosts may already have.
  """

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"
  @modify_scope "https://www.googleapis.com/auth/gmail.modify"

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(_operation_id, %{scopes: scopes}) when is_list(scopes) do
    cond do
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      true -> [@metadata_scope]
    end
  end

  defp required_for_operation(_operation_id, _connection), do: [@metadata_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
