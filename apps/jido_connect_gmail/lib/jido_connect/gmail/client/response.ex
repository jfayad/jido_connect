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

  defp label!(payload) do
    case Normalizer.label(payload) do
      {:ok, label} -> label
      {:error, error} -> raise error
    end
  end
end
