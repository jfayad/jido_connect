defmodule Jido.Connect.Slack.ScopeResolver do
  @moduledoc """
  Resolves Slack scopes whose requirements depend on action input.

  Slack's `conversations.list` changes required scopes based on the requested
  conversation types, so the static DSL scopes represent the default public
  channel case and this resolver tightens checks for private channels, DMs, and
  multi-person DMs. Slack history reads use the same conversation distinctions.
  """

  @conversation_type_scopes %{
    "public_channel" => "channels:read",
    "private_channel" => "groups:read",
    "im" => "im:read",
    "mpim" => "mpim:read"
  }

  @conversation_history_scopes %{
    "public_channel" => "channels:history",
    "private_channel" => "groups:history",
    "im" => "im:history",
    "mpim" => "mpim:history"
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

  def required_scopes(%{id: "slack.thread.replies"}, input, _connection) do
    input
    |> requested_thread_type()
    |> then(&Map.get(@conversation_history_scopes, &1, "channels:history"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.thread.replies"}, input, connection) do
    required_scopes(%{id: "slack.thread.replies"}, input, connection)
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

  defp requested_thread_type(input) do
    case Map.get(input, :conversation_type, Map.get(input, "conversation_type")) do
      nil -> type_from_channel(Map.get(input, :channel, Map.get(input, "channel")))
      type -> type |> to_string() |> String.trim()
    end
  end

  defp type_from_channel("C" <> _rest), do: "public_channel"
  defp type_from_channel("G" <> _rest), do: "private_channel"
  defp type_from_channel("D" <> _rest), do: "im"
  defp type_from_channel(_channel), do: "public_channel"
end
