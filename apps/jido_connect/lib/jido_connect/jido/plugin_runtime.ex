defmodule Jido.Connect.JidoPluginRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Jido.{PluginProjection, ToolAvailability}

  def filtered_actions(%PluginProjection{} = projection, config) do
    allowed = allowed_set(config, :allowed_actions)

    Enum.filter(projection.actions, fn action ->
      is_nil(allowed) or MapSet.member?(allowed, action.action_id)
    end)
  end

  def filtered_sensors(%PluginProjection{} = projection, config) do
    allowed = allowed_set(config, :allowed_triggers)

    Enum.filter(projection.sensors, fn sensor ->
      is_nil(allowed) or MapSet.member?(allowed, sensor.trigger_id)
    end)
  end

  def subscriptions(%PluginProjection{} = projection, config, _context) do
    projection
    |> filtered_sensors(config)
    |> Enum.filter(&(&1.kind == :poll))
    |> Enum.map(fn sensor ->
      {sensor.module, Map.get(config, :trigger_config, %{})}
    end)
  end

  def tool_availability(%PluginProjection{} = projection, config) do
    action_tools =
      Enum.map(projection.actions, fn action ->
        availability(action.action_id, action.scopes, config, :allowed_actions)
      end)

    sensor_tools =
      Enum.map(projection.sensors, fn sensor ->
        availability(sensor.trigger_id, sensor.scopes, config, :allowed_triggers)
      end)

    action_tools ++ sensor_tools
  end

  defp availability(tool, scopes, config, allowed_key) do
    allowed = allowed_set(config, allowed_key)
    connection = Map.get(config, :connection)
    connection_id = Map.get(config, :connection_id)

    cond do
      allowed && not MapSet.member?(allowed, tool) ->
        %ToolAvailability{tool: tool, state: :disabled_by_policy}

      match?(%Connect.Connection{}, connection) ->
        missing_scopes = scopes -- connection.scopes

        if missing_scopes == [] do
          %ToolAvailability{tool: tool, state: :available, connection_id: connection.id}
        else
          %ToolAvailability{
            tool: tool,
            state: :missing_scopes,
            connection_id: connection.id,
            missing_scopes: missing_scopes
          }
        end

      is_binary(connection_id) ->
        %ToolAvailability{tool: tool, state: :available, connection_id: connection_id}

      true ->
        %ToolAvailability{
          tool: tool,
          state: :connection_required,
          connection_selector: Map.get(config, :connection_selector)
        }
    end
  end

  defp allowed_set(config, key) do
    case Map.get(config, key) do
      nil -> nil
      values when is_list(values) -> MapSet.new(values)
      values -> MapSet.new(List.wrap(values))
    end
  end
end
