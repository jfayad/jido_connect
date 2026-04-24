defmodule Jido.Connect.JidoSensorRuntime do
  @moduledoc false

  alias Jido.Connect
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
         {:ok, lease} <- credential_lease(context),
         {:ok, result} <-
           Connect.poll(
             projection.integration_module.integration(),
             projection.trigger_id,
             Map.get(state, :config, %{}),
             context: integration_context,
             credential_lease: lease,
             checkpoint: Map.get(context, :checkpoint)
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
      claims: Map.get(context, :claims, %{}),
      metadata: Map.get(context, :metadata, %{})
    })
  end

  defp integration_context(_context), do: {:error, :context_required}

  defp credential_lease(%{credential_lease: %Connect.CredentialLease{} = lease}),
    do: {:ok, lease}

  defp credential_lease(_context), do: {:error, :credential_lease_required}
end
