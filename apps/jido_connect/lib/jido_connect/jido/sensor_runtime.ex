defmodule Jido.Connect.JidoSensorRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.ConnectionSelector
  alias Jido.Connect.Error
  alias Jido.Connect.Jido.SensorProjection

  def init(%SensorProjection{} = projection, config, context) when is_map(config) do
    state = %{projection: projection, config: config, context: context}

    case projection.kind do
      :poll -> {:ok, state, [{:schedule, projection.interval_ms || 300_000}]}
      _other -> {:ok, state}
    end
  end

  def handle_event(%SensorProjection{kind: :poll} = projection, :tick, state)
      when is_map(state) do
    context = Map.get(state, :context, %{})

    with {:ok, integration_context} <- integration_context(context),
         {:ok, integration_context} <-
           resolve_context_connection(integration_context, context, projection),
         {:ok, lease} <- credential_lease(context),
         {:ok, result} <-
           Connect.poll(
             projection.integration_module.integration(),
             projection.trigger_id,
             Map.get(state, :config, %{}),
             runtime_opts(context, integration_context, lease)
           ) do
      signals = Enum.map(result.signals, &signal!(projection, &1))

      directives =
        Enum.map(signals, &{:emit, &1}) ++ [{:schedule, projection.interval_ms || 300_000}]

      {:ok, state, directives}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_event(_projection, _event, state), do: {:ok, state}

  defp signal!(%SensorProjection{} = projection, payload) do
    Jido.Signal.new!(
      projection.signal_type,
      payload,
      source: projection.signal_source
    )
  end

  defp integration_context(%{integration_context: %Connect.Context{} = context}),
    do: {:ok, context}

  defp integration_context(%{context: %Connect.Context{} = context}), do: {:ok, context}

  defp integration_context(%{tenant_id: tenant_id, actor: actor} = context) do
    Connect.Context.new(%{
      tenant_id: tenant_id,
      actor: actor,
      connection: Map.get(context, :connection),
      connection_selector: Map.get(context, :connection_selector),
      claims: Map.get(context, :claims, %{}),
      metadata: Map.get(context, :metadata, %{})
    })
  end

  defp integration_context(_context), do: {:error, Error.context_required()}

  defp resolve_context_connection(
         %Connect.Context{connection: %Connect.Connection{}} = context,
         _runtime_context,
         _projection
       ),
       do: {:ok, context}

  defp resolve_context_connection(
         %Connect.Context{connection_selector: %ConnectionSelector{} = selector} = context,
         runtime_context,
         projection
       ) do
    resolver = Map.get(runtime_context, :connection_resolver)

    case ConnectionSelector.resolve(selector, resolver, projection, runtime_context) do
      {:ok, %Connect.Connection{} = connection} ->
        if ConnectionSelector.matches_connection?(selector, connection) do
          {:ok, %{context | connection: connection}}
        else
          {:error,
           Error.connection_required(%{
             trigger_id: projection.trigger_id,
             connection_selector: selector,
             mismatch: ConnectionSelector.selector_mismatch(selector, connection)
           })}
        end

      {:error, %_{} = error} ->
        {:error, error}

      :error ->
        {:error,
         Error.connection_required(%{
           trigger_id: projection.trigger_id,
           connection_selector: selector
         })}
    end
  end

  defp resolve_context_connection(%Connect.Context{} = context, _runtime_context, _projection),
    do: {:ok, context}

  defp credential_lease(%{credential_lease: %Connect.CredentialLease{} = lease}),
    do: {:ok, lease}

  defp credential_lease(_context), do: {:error, Error.credential_lease_required()}

  defp runtime_opts(runtime_context, integration_context, lease) do
    %{
      context: integration_context,
      credential_lease: lease,
      checkpoint: Map.get(runtime_context, :checkpoint),
      policy: Map.get(runtime_context, :policy),
      policy_context: Map.get(runtime_context, :policy_context, %{})
    }
  end
end
