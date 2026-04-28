defmodule Jido.Connect.JidoActionRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.ConnectionSelector
  alias Jido.Connect.Error
  alias Jido.Connect.Jido.ActionProjection

  def run(%ActionProjection{} = projection, params, agent_context) when is_map(params) do
    with {:ok, context} <- integration_context(agent_context),
         {:ok, context} <- resolve_context_connection(context, agent_context, projection),
         {:ok, lease} <- credential_lease(agent_context) do
      Connect.invoke(
        projection.integration_module.integration(),
        projection.action_id,
        params,
        runtime_opts(agent_context, context, lease)
      )
    end
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
         _agent_context,
         _projection
       ),
       do: {:ok, context}

  defp resolve_context_connection(
         %Connect.Context{connection_selector: %ConnectionSelector{} = selector} = context,
         agent_context,
         projection
       ) do
    resolver = Map.get(agent_context, :connection_resolver)

    case ConnectionSelector.resolve(selector, resolver, projection, agent_context) do
      {:ok, %Connect.Connection{} = connection} ->
        if ConnectionSelector.matches_connection?(selector, connection) do
          {:ok, %{context | connection: connection}}
        else
          {:error,
           Error.connection_required(%{
             action_id: projection.action_id,
             connection_selector: selector,
             mismatch: ConnectionSelector.selector_mismatch(selector, connection)
           })}
        end

      {:error, %_{} = error} ->
        {:error, error}

      :error ->
        {:error,
         Error.connection_required(%{
           action_id: projection.action_id,
           connection_selector: selector
         })}
    end
  end

  defp resolve_context_connection(%Connect.Context{} = context, _agent_context, _projection),
    do: {:ok, context}

  defp credential_lease(%{credential_lease: %Connect.CredentialLease{} = lease}),
    do: {:ok, lease}

  defp credential_lease(_context), do: {:error, Error.credential_lease_required()}

  defp runtime_opts(agent_context, context, lease) do
    %{
      context: context,
      credential_lease: lease,
      policy: Map.get(agent_context, :policy),
      policy_context: Map.get(agent_context, :policy_context, %{})
    }
  end
end
