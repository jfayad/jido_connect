defmodule Jido.Connect.MCP.EndpointResolver do
  @moduledoc false

  alias Jido.Connect.Error

  def resolve(endpoint_id) when is_atom(endpoint_id), do: resolve(Atom.to_string(endpoint_id))

  def resolve(endpoint_id) when is_binary(endpoint_id) do
    case Jido.MCP.ClientPool.resolve_endpoint_id(endpoint_id) do
      {:ok, endpoint_id} ->
        {:ok, endpoint_id}

      {:error, reason} ->
        {:error,
         Error.validation("Unknown MCP endpoint",
           reason: :unknown_mcp_endpoint,
           subject: endpoint_id,
           details: %{mcp_reason: reason}
         )}
    end
  end
end
