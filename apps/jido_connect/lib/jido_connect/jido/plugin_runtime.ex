defmodule Jido.Connect.JidoPluginRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Authorization
  alias Jido.Connect.ConnectionSelector
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
        connection_availability(operation, connection, config)

      is_binary(connection_id) and not is_nil(connection_resolver) ->
        case ConnectionSelector.resolve(connection_id, connection_resolver, operation, config) do
          {:ok, %Connect.Connection{} = resolved_connection} ->
            connection_availability(operation, resolved_connection, config)

          {:error, %Connect.Error.AuthError{} = error} ->
            connection_required(tool, connection_id, error)

          {:error, %_{} = error} ->
            configuration_unavailable(tool, connection_id, error)

          _other ->
            connection_required(tool, connection_id)
        end

      not is_nil(raw_connection_selector) and not is_nil(connection_resolver) ->
        selector = connection_selector || raw_connection_selector

        case ConnectionSelector.resolve(selector, connection_resolver, operation, config) do
          {:ok, %Connect.Connection{} = resolved_connection} ->
            if connection_selector_matches?(selector, resolved_connection) do
              connection_availability(operation, resolved_connection, config)
            else
              connection_required(tool, selector)
            end

          {:error, %Connect.Error.AuthError{} = error} ->
            connection_required(tool, selector, error)

          {:error, %_{} = error} ->
            configuration_unavailable(tool, selector, error)

          _other ->
            connection_required(tool, selector)
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

  defp connection_required(tool, connection_id, error) when is_binary(connection_id) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :connection_required,
      connection_id: connection_id,
      metadata: %{error: Connect.Error.to_map(error)}
    })
  end

  defp connection_required(tool, %ConnectionSelector{} = selector, error) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :connection_required,
      connection_id: selector.connection_id,
      connection_selector: selector,
      metadata: %{error: Connect.Error.to_map(error)}
    })
  end

  defp connection_required(tool, selector, error) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :connection_required,
      connection_selector: selector,
      metadata: %{error: Connect.Error.to_map(error)}
    })
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

  defp connection_selector_matches?(%ConnectionSelector{} = selector, connection) do
    ConnectionSelector.matches_connection?(selector, connection)
  end

  defp connection_selector_matches?(_selector, _connection), do: true

  defp allowed_set(config, key) do
    case Map.get(config, key) do
      nil -> nil
      values when is_list(values) -> MapSet.new(values)
      values -> MapSet.new(List.wrap(values))
    end
  end

  defp connection_availability(operation, %Connect.Connection{} = connection, config) do
    tool = operation_id(operation)

    case Authorization.connection_availability(operation, connection, %{},
           context: policy_context(config),
           policy: Map.get(config, :policy),
           policy_context: Map.get(config, :policy_context, %{})
         ) do
      {:available, _required_scopes} ->
        ToolAvailability.new!(%{tool: tool, state: :available, connection_id: connection.id})

      {:missing_scopes, missing_scopes} ->
        ToolAvailability.new!(%{
          tool: tool,
          state: :missing_scopes,
          connection_id: connection.id,
          missing_scopes: missing_scopes
        })

      :disabled_by_policy ->
        ToolAvailability.new!(%{
          tool: tool,
          state: :disabled_by_policy,
          connection_id: connection.id
        })

      :connection_required ->
        ToolAvailability.new!(%{
          tool: tool,
          state: :connection_required,
          connection_id: connection.id
        })

      {:configuration_error, error} ->
        ToolAvailability.new!(%{
          tool: tool,
          state: :configuration_error,
          connection_id: connection.id,
          metadata: %{error: Connect.Error.to_map(error)}
        })
    end
  end

  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(%{trigger_id: trigger_id}), do: trigger_id

  defp policy_context(config) do
    Map.get(config, :integration_context) || Map.get(config, :context)
  end

  defp configuration_unavailable(tool, connection_id, error) when is_binary(connection_id) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :configuration_error,
      connection_id: connection_id,
      metadata: %{error: Connect.Error.to_map(error)}
    })
  end

  defp configuration_unavailable(tool, %ConnectionSelector{} = selector, error) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :configuration_error,
      connection_id: selector.connection_id,
      connection_selector: selector,
      metadata: %{error: Connect.Error.to_map(error)}
    })
  end

  defp configuration_unavailable(tool, selector, error) do
    ToolAvailability.new!(%{
      tool: tool,
      state: :configuration_error,
      connection_selector: selector,
      metadata: %{error: Connect.Error.to_map(error)}
    })
  end
end
