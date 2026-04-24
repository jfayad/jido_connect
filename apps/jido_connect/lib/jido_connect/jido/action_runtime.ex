defmodule Jido.Connect.JidoActionRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Jido.ActionProjection

  def run(%ActionProjection{} = projection, params, agent_context) when is_map(params) do
    with {:ok, context} <- integration_context(agent_context),
         {:ok, lease} <- credential_lease(agent_context) do
      Connect.invoke(
        projection.integration_module.integration(),
        projection.action_id,
        params,
        context: context,
        credential_lease: lease
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
      claims: Map.get(context, :claims, %{}),
      metadata: Map.get(context, :metadata, %{})
    })
  end

  defp integration_context(_context), do: {:error, :context_required}

  defp credential_lease(%{credential_lease: %Connect.CredentialLease{} = lease}),
    do: {:ok, lease}

  defp credential_lease(_context), do: {:error, :credential_lease_required}
end
