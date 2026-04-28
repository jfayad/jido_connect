defmodule Jido.Connect.Authorization do
  @moduledoc """
  Runtime authorization helpers shared by generated adapters and host UIs.

  This module keeps provider handlers out of auth policy. It validates the
  host-owned durable connection, the short-lived credential lease, the
  operation's supported auth profiles, and static or dynamic scopes before any
  provider code runs.
  """

  alias Jido.Connect.{
    ActionSpec,
    Connection,
    Context,
    CredentialLease,
    Error,
    ScopeRequirements,
    TriggerSpec
  }

  @type operation :: ActionSpec.t() | TriggerSpec.t() | map()

  @doc """
  Authorizes an operation against context and a credential lease.

  The flow is intentionally strict:

  - lease must be active
  - context must include a connected connection
  - lease connection id and optional binding metadata must match the connection
  - connection profile must be allowed by the operation
  - dynamic required scopes must be present in the lease's effective scopes
  """
  @spec authorize(operation(), map(), Context.t(), CredentialLease.t()) ::
          :ok | {:error, Error.error()}
  def authorize(operation, input, %Context{} = context, %CredentialLease{} = lease)
      when is_map(input) do
    with :ok <- CredentialLease.require_unexpired(lease),
         {:ok, connection} <- fetch_connection(context, operation),
         :ok <- require_connected(connection, operation),
         :ok <- require_lease_connection(connection, lease),
         :ok <- require_supported_profile(operation, connection),
         :ok <- CredentialLease.validate_connection_binding(lease, connection),
         {:ok, required_scopes} <- required_scopes(operation, input, connection),
         :ok <- require_effective_scopes(connection, lease, required_scopes) do
      :ok
    end
  end

  @doc """
  Evaluates connection-only availability for an operation.

  This is useful before a credential lease exists, for example when rendering a
  host UI or generated Jido plugin tool list. Lease expiration and lease scope
  reduction are intentionally not checked here.
  """
  @spec connection_availability(operation(), Connection.t(), map()) ::
          {:available, [String.t()]} | {:missing_scopes, [String.t()]} | :connection_required
  def connection_availability(operation, %Connection{} = connection, input \\ %{})
      when is_map(input) do
    with :ok <- require_connected(connection, operation),
         :ok <- require_supported_profile(operation, connection),
         {:ok, required_scopes} <- required_scopes(operation, input, connection) do
      missing_scopes = required_scopes -- connection.scopes

      if missing_scopes == [] do
        {:available, required_scopes}
      else
        {:missing_scopes, missing_scopes}
      end
    else
      _other -> :connection_required
    end
  end

  @doc "Returns all auth profiles accepted by an action, trigger, or projection."
  @spec operation_auth_profiles(operation()) :: [atom()]
  def operation_auth_profiles(operation) do
    case Map.get(operation, :auth_profiles, []) do
      [] -> [Map.fetch!(operation, :auth_profile)]
      profiles -> profiles
    end
  end

  @doc "Returns a stable action/trigger id for error details and host UIs."
  @spec operation_id(operation()) :: String.t() | nil
  def operation_id(%{action_id: action_id}), do: action_id
  def operation_id(%{trigger_id: trigger_id}), do: trigger_id
  def operation_id(%{id: id}), do: id
  def operation_id(_operation), do: nil

  @doc "Resolves static or provider-specific scopes for an operation."
  @spec required_scopes(operation(), map(), Connection.t() | nil) ::
          {:ok, [String.t()]} | {:error, Error.error()}
  def required_scopes(operation, input, connection) do
    ScopeRequirements.required_scopes(operation, input, connection)
  end

  defp fetch_connection(%Context{connection: %Connection{} = connection}, _operation) do
    {:ok, connection}
  end

  defp fetch_connection(%Context{}, operation) do
    {:error, Error.connection_required(%{operation_id: operation_id(operation)})}
  end

  defp require_connected(%Connection{status: :connected}, _operation), do: :ok

  defp require_connected(%Connection{} = connection, operation) do
    {:error,
     Error.connection_required(%{
       operation_id: operation_id(operation),
       connection_id: connection.id,
       status: connection.status
     })}
  end

  defp require_lease_connection(%Connection{} = connection, %CredentialLease{} = lease) do
    if connection.id == lease.connection_id do
      :ok
    else
      {:error, Error.credential_connection_mismatch(connection.id, lease.connection_id)}
    end
  end

  defp require_supported_profile(operation, %Connection{} = connection) do
    allowed_profiles = operation_auth_profiles(operation)

    if connection.profile in allowed_profiles do
      :ok
    else
      {:error,
       Error.unsupported_auth_profile(connection.id, connection.profile, allowed_profiles)}
    end
  end

  defp require_effective_scopes(%Connection{} = connection, %CredentialLease{} = lease, scopes) do
    missing_scopes = scopes -- CredentialLease.effective_scopes(lease, connection)

    if missing_scopes == [] do
      :ok
    else
      {:error, Error.missing_scopes(connection.id, missing_scopes)}
    end
  end
end
