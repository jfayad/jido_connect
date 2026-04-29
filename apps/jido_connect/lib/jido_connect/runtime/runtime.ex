defmodule Jido.Connect.Runtime do
  @moduledoc false

  alias Jido.Connect.{
    ActionSpec,
    Authorization,
    Callback,
    Context,
    CredentialLease,
    Error,
    Spec,
    Telemetry,
    TriggerSpec
  }

  @doc false
  def invoke(%Spec{} = integration, action_id, input, opts) do
    Telemetry.span(:invoke, telemetry_metadata(integration, action_id, opts), fn ->
      do_invoke(integration, action_id, input, opts)
    end)
  end

  @doc false
  def poll(%Spec{} = integration, trigger_id, config, opts) do
    Telemetry.span(:poll, telemetry_metadata(integration, trigger_id, opts), fn ->
      do_poll(integration, trigger_id, config, opts)
    end)
  end

  defp do_invoke(%Spec{} = integration, action_id, input, opts) do
    with {:ok, action} <- find_action(integration, action_id),
         {:ok, parsed_input} <- parse_schema(action.input_schema, input, :input),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- Authorization.authorize(action, parsed_input, context, lease, auth_opts(opts)),
         {:ok, output} <-
           run_action_handler(action, parsed_input, %{
             integration: integration,
             action: action,
             context: context,
             credential_lease: lease,
             credentials: lease.fields
           }),
         {:ok, parsed_output} <- parse_schema(action.output_schema, output, :output) do
      {:ok, parsed_output}
    end
  end

  defp do_poll(%Spec{} = integration, trigger_id, config, opts) do
    with {:ok, trigger} <- find_trigger(integration, trigger_id),
         {:ok, parsed_config} <- parse_schema(trigger.config_schema, config, :config),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- Authorization.authorize(trigger, parsed_config, context, lease, auth_opts(opts)),
         {:ok, result} <-
           run_poll_handler(trigger, parsed_config, %{
             integration: integration,
             trigger: trigger,
             context: context,
             credential_lease: lease,
             credentials: lease.fields,
             checkpoint: get_option(opts, :checkpoint)
           }),
         {:ok, signals} <- validate_signals(trigger, Map.get(result, :signals, [])) do
      {:ok, %{signals: signals, checkpoint: Map.get(result, :checkpoint)}}
    end
  end

  defp find_action(%Spec{} = integration, action_id) do
    case Enum.find(integration.actions, &(&1.id == action_id)) do
      %ActionSpec{} = action -> {:ok, action}
      nil -> {:error, Error.unknown_action(action_id)}
    end
  end

  defp find_trigger(%Spec{} = integration, trigger_id) do
    case Enum.find(integration.triggers, &(&1.id == trigger_id)) do
      %TriggerSpec{} = trigger -> {:ok, trigger}
      nil -> {:error, Error.unknown_trigger(trigger_id)}
    end
  end

  defp fetch_context(opts) do
    case fetch_option(opts, :context) do
      {:ok, %Context{} = context} ->
        {:ok, context}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> Context.new() |> normalize_schema_result(:context)

      :error ->
        {:error, Error.context_required()}
    end
  end

  defp fetch_credential_lease(opts) do
    case fetch_option(opts, :credential_lease) do
      {:ok, %CredentialLease{} = lease} ->
        {:ok, lease}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> CredentialLease.new() |> normalize_schema_result(:credential_lease)

      :error ->
        {:error, Error.credential_lease_required()}
    end
  end

  defp run_action_handler(%ActionSpec{} = action, input, context) do
    with {:ok, result} <-
           Callback.call(action.handler, :run, [input, context],
             phase: :handler,
             details: %{operation_id: action.id}
           ) do
      normalize_handler_result(result, :handler, action.id)
    end
  end

  defp run_poll_handler(%TriggerSpec{} = trigger, config, context) do
    with {:ok, result} <-
           Callback.call(trigger.handler, :poll, [config, context],
             phase: :handler,
             details: %{operation_id: trigger.id}
           ) do
      normalize_handler_result(result, :handler, trigger.id)
    end
  end

  defp normalize_handler_result({:ok, value}, _phase, _operation_id), do: {:ok, value}

  defp normalize_handler_result({:error, %_module{} = error}, phase, operation_id) do
    if Error.error?(error) do
      {:error, error}
    else
      normalize_handler_result({:error, Map.from_struct(error)}, phase, operation_id)
    end
  end

  defp normalize_handler_result({:error, reason}, phase, operation_id) do
    {:error,
     Error.execution("Provider handler failed",
       phase: phase,
       details: %{
         operation_id: operation_id,
         error: Jido.Connect.Sanitizer.sanitize(reason, :transport)
       }
     )}
  end

  defp normalize_handler_result(result, phase, operation_id) do
    {:error,
     Error.execution("Provider handler returned an invalid result",
       phase: phase,
       details: %{
         operation_id: operation_id,
         returned: Jido.Connect.Sanitizer.sanitize(result, :transport)
       }
     )}
  end

  defp validate_signals(%TriggerSpec{} = trigger, signals) when is_list(signals) do
    Enum.reduce_while(signals, {:ok, []}, fn signal, {:ok, acc} ->
      case Zoi.parse(trigger.signal_schema, signal) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        {:error, error} -> {:halt, {:error, Error.zoi(:signal, error, %{trigger_id: trigger.id})}}
      end
    end)
  end

  defp parse_schema(schema, value, reason) do
    case Zoi.parse(schema, value) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, errors} -> {:error, Error.zoi(reason, errors)}
    end
  end

  defp normalize_schema_result({:ok, parsed}, _reason), do: {:ok, parsed}
  defp normalize_schema_result({:error, errors}, reason), do: {:error, Error.zoi(reason, errors)}

  defp fetch_option(opts, key) when is_list(opts), do: Keyword.fetch(opts, key)
  defp fetch_option(opts, key) when is_map(opts), do: Map.fetch(opts, key)

  defp get_option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp get_option(opts, key) when is_map(opts), do: Map.get(opts, key)

  defp auth_opts(opts) do
    %{
      policy: get_option(opts, :policy),
      policy_context: get_option(opts, :policy_context)
    }
  end

  defp telemetry_metadata(%Spec{} = integration, operation_id, opts) do
    context = get_option(opts, :context)
    lease = get_option(opts, :credential_lease)
    connection = context_connection(context)

    %{
      integration_id: integration.id,
      operation_id: operation_id,
      tenant_id: context_field(context, :tenant_id),
      actor_type: actor_type(context),
      connection_id: connection_field(connection, :id),
      auth_profile: connection_field(connection, :profile),
      credential_lease_connection_id: credential_lease_connection_id(lease)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp context_connection(%Context{connection: connection}), do: connection
  defp context_connection(%{connection: connection}), do: connection
  defp context_connection(_context), do: nil

  defp context_field(%Context{} = context, field), do: Map.get(context, field)
  defp context_field(context, field) when is_map(context), do: Map.get(context, field)
  defp context_field(_context, _field), do: nil

  defp actor_type(%Context{actor: actor}), do: actor_type(actor)
  defp actor_type(%{actor: actor}), do: actor_type(actor)
  defp actor_type(%{type: type}), do: type
  defp actor_type(%{"type" => type}), do: type
  defp actor_type(_context), do: nil

  defp connection_field(%Jido.Connect.Connection{} = connection, field),
    do: Map.get(connection, field)

  defp connection_field(connection, field) when is_map(connection), do: Map.get(connection, field)
  defp connection_field(_connection, _field), do: nil

  defp credential_lease_connection_id(%CredentialLease{connection_id: connection_id}),
    do: connection_id

  defp credential_lease_connection_id(%{connection_id: connection_id}), do: connection_id
  defp credential_lease_connection_id(_lease), do: nil
end
