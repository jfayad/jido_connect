defmodule Jido.Connect.Gmail.Client.Response do
  @moduledoc "Gmail response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Gmail.{Client.Transport, Normalizer}

  def handle_profile_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.profile(body)
  end

  def handle_profile_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail profile response was invalid", body)
  end

  def handle_profile_response(response), do: Transport.handle_error_response(response)

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    labels =
      body
      |> Data.get("labels", [])
      |> Enum.map(&label!/1)

    {:ok, %{labels: labels}}
  end

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail label list response was invalid", body)
  end

  def handle_label_list_response(response), do: Transport.handle_error_response(response)

  def handle_label_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.label(body)
  end

  def handle_label_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail label response was invalid", body)
  end

  def handle_label_response(response), do: Transport.handle_error_response(response)

  def handle_message_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    messages =
      body
      |> Data.get("messages", [])
      |> Enum.map(&message!/1)

    {:ok,
     %{
       messages: messages,
       next_page_token: Data.get(body, "nextPageToken"),
       result_size_estimate: Data.get(body, "resultSizeEstimate")
     }
     |> Data.compact()}
  end

  def handle_message_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail message list response was invalid", body)
  end

  def handle_message_list_response(response), do: Transport.handle_error_response(response)

  def handle_message_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.message(body)
  end

  def handle_message_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail message response was invalid", body)
  end

  def handle_message_response(response), do: Transport.handle_error_response(response)

  def handle_thread_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    threads =
      body
      |> Data.get("threads", [])
      |> Enum.map(&thread!/1)

    {:ok,
     %{
       threads: threads,
       next_page_token: Data.get(body, "nextPageToken"),
       result_size_estimate: Data.get(body, "resultSizeEstimate")
     }
     |> Data.compact()}
  end

  def handle_thread_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail thread list response was invalid", body)
  end

  def handle_thread_list_response(response), do: Transport.handle_error_response(response)

  def handle_thread_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.thread(body)
  end

  def handle_thread_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail thread response was invalid", body)
  end

  def handle_thread_response(response), do: Transport.handle_error_response(response)

  def handle_draft_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.draft(body)
  end

  def handle_draft_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail draft response was invalid", body)
  end

  def handle_draft_response(response), do: Transport.handle_error_response(response)

  defp label!(payload) do
    case Normalizer.label(payload) do
      {:ok, label} -> label
      {:error, error} -> raise error
    end
  end

  defp message!(payload) do
    case Normalizer.message(payload) do
      {:ok, message} -> message
      {:error, error} -> raise error
    end
  end

  defp thread!(payload) do
    case Normalizer.thread(payload) do
      {:ok, thread} -> thread
      {:error, error} -> raise error
    end
  end
end
