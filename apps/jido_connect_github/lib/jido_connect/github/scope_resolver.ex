defmodule Jido.Connect.GitHub.ScopeResolver do
  @moduledoc false

  def required_scopes(operation, _input, %{profile: :installation}) do
    case operation_id(operation) do
      "github.repo.list" -> ["metadata:read"]
      "github.issue_comment.create" -> ["metadata:read", "issues:write"]
      "github.issue.create" -> ["metadata:read", "issues:write"]
      "github.issue.list" -> ["metadata:read", "issues:read"]
      "github.pull_request.create" -> ["metadata:read", "pull_requests:write"]
      "github.pull_request.merge" -> ["metadata:read", "pull_requests:write", "contents:write"]
      "github.pull_request.update" -> ["metadata:read", "pull_requests:write"]
      "github.pull_request.list" -> ["metadata:read", "pull_requests:read"]
      "github.issue.new" -> ["metadata:read", "issues:read"]
      _other -> Map.get(operation, :scopes, [])
    end
  end

  def required_scopes(operation, _input, _connection), do: Map.get(operation, :scopes, [])

  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(%{trigger_id: trigger_id}), do: trigger_id
  defp operation_id(%{id: id}), do: id
end
