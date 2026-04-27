defmodule Jido.Connect.Slack.ScopeResolver do
  @moduledoc """
  Resolves Slack scopes whose requirements depend on action input.

  Slack's `conversations.list` changes required scopes based on the requested
  conversation types, so the static DSL scopes represent the default public
  channel case and this resolver tightens checks for private channels, DMs, and
  multi-person DMs.
  """

  @conversation_type_scopes %{
    "public_channel" => "channels:read",
    "private_channel" => "groups:read",
    "im" => "im:read",
    "mpim" => "mpim:read"
  }

  def required_scopes(%{id: "slack.channel.list"}, input, _connection) do
    input
    |> requested_types()
    |> Enum.map(&Map.get(@conversation_type_scopes, &1, "channels:read"))
    |> Enum.uniq()
  end

  def required_scopes(%{action_id: "slack.channel.list"}, input, connection) do
    required_scopes(%{id: "slack.channel.list"}, input, connection)
  end

  def required_scopes(operation, _input, _connection), do: Map.get(operation, :scopes, [])

  defp requested_types(input) do
    input
    |> Map.get(:types, Map.get(input, "types", "public_channel"))
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> ["public_channel"]
      types -> types
    end
  end
end
