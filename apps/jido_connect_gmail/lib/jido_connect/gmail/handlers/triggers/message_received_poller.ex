defmodule Jido.Connect.Gmail.Handlers.Triggers.MessageReceivedPoller do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Gmail.Client

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      poll_messages(
        client,
        normalize_config(config),
        checkpoint,
        Map.get(credentials, :access_token)
      )
    end
  end

  defp poll_messages(client, _config, checkpoint, access_token) when checkpoint in [nil, ""] do
    with {:ok, profile} <- client.get_profile(%{}, access_token) do
      case Map.get(profile, :history_id) do
        history_id when is_binary(history_id) and history_id != "" ->
          {:ok, %{signals: [], checkpoint: history_id}}

        _missing ->
          invalid_missing_history_id()
      end
    end
  end

  defp poll_messages(client, config, checkpoint, access_token) do
    params =
      config
      |> Map.put(:start_history_id, checkpoint)
      |> Map.put(:history_types, ["messageAdded"])

    fetch_history_pages(client, params, access_token, [], nil, MapSet.new())
  end

  defp fetch_history_pages(client, params, access_token, signals, latest_history_id, seen) do
    with {:ok, result} <- client.list_history(params, access_token) do
      latest_history_id = Map.get(result, :history_id) || latest_history_id
      signals = signals ++ history_signals(Map.get(result, :history, []))

      case Map.get(result, :next_page_token) do
        nil ->
          {:ok,
           %{
             signals: dedupe_signals(signals),
             checkpoint: latest_history_id || Map.fetch!(params, :start_history_id)
           }}

        page_token ->
          if MapSet.member?(seen, page_token) do
            invalid_repeated_page_token(page_token)
          else
            fetch_history_pages(
              client,
              Map.put(params, :page_token, page_token),
              access_token,
              signals,
              latest_history_id,
              MapSet.put(seen, page_token)
            )
          end
      end
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:label_id, "INBOX")
  end

  defp history_signals(history) when is_list(history) do
    Enum.flat_map(history, fn history_record ->
      history_id = Map.get(history_record, :history_id)

      history_record
      |> Map.get(:messages_added, [])
      |> Enum.map(&message_signal(&1, history_id))
    end)
  end

  defp history_signals(_history), do: []

  defp message_signal(message, history_id) do
    public_message = public_map(message)

    %{
      message_id: Map.get(message, :message_id),
      thread_id: Map.get(message, :thread_id),
      history_id: Map.get(message, :history_id) || history_id,
      label_ids: Map.get(message, :label_ids, []),
      snippet: Map.get(message, :snippet),
      internal_date: Map.get(message, :internal_date),
      size_estimate: Map.get(message, :size_estimate),
      headers: Map.get(message, :headers, []),
      message: public_message
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp dedupe_signals(signals) do
    {_seen, unique} =
      Enum.reduce(signals, {MapSet.new(), []}, fn signal, {seen, acc} ->
        key = Map.get(signal, :message_id)

        cond do
          is_nil(key) ->
            {seen, acc}

          MapSet.member?(seen, key) ->
            {seen, acc}

          true ->
            {MapSet.put(seen, key), [signal | acc]}
        end
      end)

    Enum.reverse(unique)
  end

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp invalid_missing_history_id do
    {:error,
     Error.provider("Gmail profile response was missing historyId",
       provider: :google,
       reason: :invalid_response,
       details: %{field: :history_id}
     )}
  end

  defp invalid_repeated_page_token(page_token) do
    {:error,
     Error.provider("Gmail history response repeated nextPageToken",
       provider: :google,
       reason: :invalid_response,
       details: %{next_page_token: page_token}
     )}
  end
end
