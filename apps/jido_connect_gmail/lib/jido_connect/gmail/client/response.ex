defmodule Jido.Connect.Gmail.Client.Response do
  @moduledoc "Gmail response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Gmail.{Client.Transport, Normalizer}

  def handle_profile_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.profile/1, "Gmail profile response was invalid")
  end

  def handle_profile_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail profile response was invalid", body)
  end

  def handle_profile_response(response), do: Transport.handle_error_response(response)

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, labels} <-
           normalize_items(
             body,
             "labels",
             &Normalizer.label/1,
             "Gmail label list response was invalid"
           ) do
      {:ok, %{labels: labels}}
    end
  end

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail label list response was invalid", body)
  end

  def handle_label_list_response(response), do: Transport.handle_error_response(response)

  def handle_label_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.label/1, "Gmail label response was invalid")
  end

  def handle_label_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail label response was invalid", body)
  end

  def handle_label_response(response), do: Transport.handle_error_response(response)

  def handle_message_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, messages} <-
           normalize_items(
             body,
             "messages",
             &Normalizer.message/1,
             "Gmail message list response was invalid"
           ) do
      {:ok,
       %{
         messages: messages,
         next_page_token: Data.get(body, "nextPageToken"),
         result_size_estimate: Data.get(body, "resultSizeEstimate")
       }
       |> Data.compact()}
    end
  end

  def handle_message_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail message list response was invalid", body)
  end

  def handle_message_list_response(response), do: Transport.handle_error_response(response)

  def handle_message_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.message/1, "Gmail message response was invalid")
  end

  def handle_message_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail message response was invalid", body)
  end

  def handle_message_response(response), do: Transport.handle_error_response(response)

  def handle_thread_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, threads} <-
           normalize_items(
             body,
             "threads",
             &Normalizer.thread/1,
             "Gmail thread list response was invalid"
           ) do
      {:ok,
       %{
         threads: threads,
         next_page_token: Data.get(body, "nextPageToken"),
         result_size_estimate: Data.get(body, "resultSizeEstimate")
       }
       |> Data.compact()}
    end
  end

  def handle_thread_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail thread list response was invalid", body)
  end

  def handle_thread_list_response(response), do: Transport.handle_error_response(response)

  def handle_thread_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.thread/1, "Gmail thread response was invalid")
  end

  def handle_thread_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail thread response was invalid", body)
  end

  def handle_thread_response(response), do: Transport.handle_error_response(response)

  def handle_history_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, history} <-
           normalize_items(
             body,
             "history",
             &history_record/1,
             "Gmail history list response was invalid"
           ) do
      {:ok,
       %{
         history: history,
         next_page_token: Data.get(body, "nextPageToken"),
         history_id: normalize_string(Data.get(body, "historyId"))
       }
       |> Data.compact()}
    end
  end

  def handle_history_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail history list response was invalid", body)
  end

  def handle_history_list_response(response), do: Transport.handle_error_response(response)

  def handle_draft_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.draft/1, "Gmail draft response was invalid")
  end

  def handle_draft_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail draft response was invalid", body)
  end

  def handle_draft_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end

  defp history_record(payload) when is_map(payload) do
    with {:ok, messages_added} <-
           normalize_items(
             payload,
             "messagesAdded",
             &message_added/1,
             "Gmail history list response was invalid"
           ) do
      {:ok,
       %{
         history_id: normalize_string(Data.get(payload, "id")),
         messages_added: messages_added
       }
       |> Data.compact()}
    end
  end

  defp history_record(_payload), do: {:error, :invalid_history_record}

  defp message_added(payload) when is_map(payload) do
    payload
    |> Data.get("message", %{})
    |> Normalizer.message()
  end

  defp message_added(_payload), do: {:error, :invalid_message_added}

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)
end
