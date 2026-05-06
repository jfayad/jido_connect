defmodule Jido.Connect.Google.Calendar.Handlers.Triggers.EventChangedPoller do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Calendar.Client

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      config = normalize_config(config)
      access_token = Map.get(credentials, :access_token)

      if checkpoint in [nil, ""] do
        initialize_checkpoint(client, config, access_token)
      else
        poll_changes(client, config, checkpoint, access_token)
      end
    end
  end

  defp initialize_checkpoint(client, config, access_token) do
    fetch_event_pages(
      client,
      Map.put(config, :show_deleted, true),
      access_token,
      [],
      nil,
      MapSet.new(),
      emit?: false
    )
  end

  defp poll_changes(client, config, checkpoint, access_token) do
    params =
      config
      |> Map.put(:sync_token, checkpoint)
      |> Map.put(:show_deleted, true)

    case fetch_event_pages(client, params, access_token, [], nil, MapSet.new([checkpoint]),
           emit?: true
         ) do
      {:error, %Error.ProviderError{status: 410} = error} ->
        expired_sync_token(checkpoint, error)

      result ->
        result
    end
  end

  defp fetch_event_pages(client, params, access_token, signals, latest_sync_token, seen, opts) do
    with {:ok, result} <- client.list_events(params, access_token) do
      signals =
        if Keyword.fetch!(opts, :emit?) do
          signals ++ Enum.map(Map.get(result, :events, []), &normalize_signal/1)
        else
          signals
        end

      latest_sync_token = Map.get(result, :next_sync_token) || latest_sync_token

      case Map.get(result, :next_page_token) do
        nil ->
          checkpoint = latest_sync_token || Map.get(params, :sync_token)

          if checkpoint in [nil, ""] do
            invalid_missing_sync_token()
          else
            {:ok, %{signals: dedupe_signals(signals), checkpoint: checkpoint}}
          end

        page_token ->
          if MapSet.member?(seen, page_token) do
            invalid_repeated_page_token(page_token)
          else
            fetch_event_pages(
              client,
              Map.put(params, :page_token, page_token),
              access_token,
              signals,
              latest_sync_token,
              MapSet.put(seen, page_token),
              opts
            )
          end
      end
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new(:page_size, 250)
    |> Map.put_new(:single_events, true)
    |> Map.put_new(:show_hidden_invitations, false)
  end

  defp normalize_signal(event) do
    %{
      event_id: Map.get(event, :event_id),
      calendar_id: Map.get(event, :calendar_id),
      status: Map.get(event, :status),
      change_type: change_type(event),
      summary: Map.get(event, :summary),
      start: Map.get(event, :start),
      end: Map.get(event, :end),
      updated: Map.get(event, :updated),
      event: public_map(event)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp change_type(%{status: "cancelled"}), do: "cancelled"
  defp change_type(_event), do: "updated"

  defp dedupe_signals(signals) do
    {_seen, unique} =
      Enum.reduce(signals, {MapSet.new(), []}, fn signal, {seen, acc} ->
        key = {Map.get(signal, :event_id), Map.get(signal, :updated)}

        cond do
          key == {nil, nil} ->
            {seen, acc}

          MapSet.member?(seen, key) ->
            {seen, acc}

          true ->
            {MapSet.put(seen, key), [signal | acc]}
        end
      end)

    Enum.reverse(unique)
  end

  defp invalid_missing_sync_token do
    {:error,
     Error.provider("Google Calendar event list response omitted nextSyncToken",
       provider: :google,
       reason: :invalid_response
     )}
  end

  defp invalid_repeated_page_token(page_token) do
    {:error,
     Error.provider("Google Calendar event list response repeated nextPageToken",
       provider: :google,
       reason: :invalid_response,
       details: %{next_page_token: page_token}
     )}
  end

  defp expired_sync_token(checkpoint, error) do
    {:error,
     Error.provider("Google Calendar event sync token expired",
       provider: :google,
       reason: :checkpoint_expired,
       status: 410,
       details: %{
         checkpoint: checkpoint,
         provider_reason: error.reason,
         provider_details: error.details
       }
     )}
  end

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value

  defp fetch_client(%{google_calendar_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
