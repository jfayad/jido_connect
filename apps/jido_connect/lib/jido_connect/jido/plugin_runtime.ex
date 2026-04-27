defmodule Jido.Connect.JidoPluginRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.ConnectionSelector
  alias Jido.Connect.Jido.{PluginProjection, ToolAvailability}
  alias Jido.Connect.ScopeRequirements

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
        availability(action, config, :allowed_actions)
      end)

    sensor_tools =
      Enum.map(projection.sensors, fn sensor ->
        availability(sensor, config, :allowed_triggers)
      end)

    action_tools ++ sensor_tools
  end

  defp availability(operation, config, allowed_key) do
    tool = operation_id(operation)
    allowed = allowed_set(config, allowed_key)
    connection = Map.get(config, :connection)
    connection_id = Map.get(config, :connection_id)
    raw_connection_selector = Map.get(config, :connection_selector)
    connection_selector = connection_selector(config)
    connection_resolver = Map.get(config, :connection_resolver)

    cond do
      allowed && not MapSet.member?(allowed, tool) ->
        ToolAvailability.new!(%{tool: tool, state: :disabled_by_policy})

      match?(%Connect.Connection{}, connection) ->
        connection_availability(operation, connection)

      is_binary(connection_id) and not is_nil(connection_resolver) ->
        case ConnectionSelector.resolve(connection_id, connection_resolver, operation, config) do
          {:ok, %Connect.Connection{} = resolved_connection} ->
            connection_availability(operation, resolved_connection)

          _other ->
            connection_required(tool, connection_id)
        end

      not is_nil(raw_connection_selector) and not is_nil(connection_resolver) ->
        case ConnectionSelector.resolve(
               connection_selector || raw_connection_selector,
               connection_resolver,
               operation,
               config
             ) do
          {:ok, %Connect.Connection{} = resolved_connection} ->
            connection_availability(operation, resolved_connection)

          _other ->
            connection_required(tool, connection_selector || raw_connection_selector)
        end

      is_binary(connection_id) or not is_nil(raw_connection_selector) ->
        connection_required(tool, connection_id || connection_selector || raw_connection_selector)

      true ->
        ToolAvailability.new!(%{
          tool: tool,
          state: :connection_required
        })
    end
  end

  defp connection_required(tool, connection_id) when is_binary(connection_id) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :connection_required,
      connection_id: connection_id
    })
  end

  defp connection_required(tool, %ConnectionSelector{} = selector) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :connection_required,
      connection_id: selector.connection_id,
      connection_selector: selector
    })
  end

  defp connection_required(tool, selector) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :connection_required,
      connection_selector: selector
    })
  end

  defp connection_selector(config) do
    case ConnectionSelector.normalize(Map.get(config, :connection_selector)) do
      {:ok, selector} -> selector
      :error -> nil
    end
  end

  defp allowed_set(config, key) do
    case Map.get(config, key) do
      nil -> nil
      values when is_list(values) -> MapSet.new(values)
      values -> MapSet.new(List.wrap(values))
    end
  end

  defp connection_availability(operation, %Connect.Connection{} = connection) do
    tool = operation_id(operation)

    with :connected <- connection.status,
         {:ok, required_scopes} <-
           ScopeRequirements.required_scopes(operation, %{}, connection) do
      missing_scopes = required_scopes -- connection.scopes

      if missing_scopes == [] do
        ToolAvailability.new!(%{tool: tool, state: :available, connection_id: connection.id})
      else
        ToolAvailability.new!(%{
          tool: tool,
          state: :missing_scopes,
          connection_id: connection.id,
          missing_scopes: missing_scopes
        })
      end
    else
      _other ->
        ToolAvailability.new!(%{
          tool: tool,
          state: :connection_required,
          connection_id: connection.id
        })
    end
  end

  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(%{trigger_id: trigger_id}), do: trigger_id
end
