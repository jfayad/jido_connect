defmodule Jido.Connect.Google.Drive.Client.Response do
  @moduledoc "Google Drive response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Drive.{Client.Transport, Normalizer}

  def handle_file_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    files =
      body
      |> Data.get("files", [])
      |> Enum.map(&file!/1)

    {:ok,
     %{
       files: files,
       next_page_token: Data.get(body, "nextPageToken")
     }
     |> Data.compact()}
  end

  def handle_file_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive file list response was invalid", body)
  end

  def handle_file_list_response(response), do: Transport.handle_error_response(response)

  def handle_file_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.file(body)
  end

  def handle_file_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive file response was invalid", body)
  end

  def handle_file_response(response), do: Transport.handle_error_response(response)

  defp file!(payload) do
    case Normalizer.file(payload) do
      {:ok, file} -> file
      {:error, error} -> raise error
    end
  end
end
