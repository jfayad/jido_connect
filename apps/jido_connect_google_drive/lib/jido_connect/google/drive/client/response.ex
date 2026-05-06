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

  def handle_file_content_response({:ok, %{status: status, body: body, headers: headers}}, params)
      when status in 200..299 and is_binary(body) do
    {:ok, normalize_file_content(body, headers, params)}
  end

  def handle_file_content_response({:ok, %{status: status, body: body}}, _params)
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive file content response was invalid", body)
  end

  def handle_file_content_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_file_delete_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       file_id: Data.get(params, :file_id),
       deleted?: true
     }}
  end

  def handle_file_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def file_to_folder({:ok, file}) do
    %{
      "id" => file.file_id,
      "name" => file.name,
      "webViewLink" => file.web_view_link,
      "createdTime" => file.created_time,
      "modifiedTime" => file.modified_time,
      "parents" => file.parents,
      "trashed" => file.trashed?,
      "shared" => file.shared?,
      "driveId" => file.drive_id
    }
    |> Normalizer.folder()
  end

  def file_to_folder({:error, reason}), do: {:error, reason}

  defp file!(payload) do
    case Normalizer.file(payload) do
      {:ok, file} -> file
      {:error, error} -> raise error
    end
  end

  defp normalize_file_content(body, headers, params) do
    base = %{
      file_id: Data.get(params, :file_id),
      mime_type: Data.get(params, :mime_type) || response_mime_type(headers),
      size: byte_size(body)
    }

    content =
      if text_content?(body) do
        %{content: body, content_base64: nil, encoding: "utf-8", binary: false}
      else
        %{content: nil, content_base64: Base.encode64(body), encoding: "base64", binary: true}
      end

    base
    |> Map.merge(content)
    |> Data.compact()
  end

  defp text_content?(content) do
    String.valid?(content) and :binary.match(content, <<0>>) == :nomatch
  end

  defp response_mime_type(headers) do
    headers
    |> header("content-type")
    |> strip_content_type_params()
  end

  defp header(headers, name) when is_map(headers) do
    headers
    |> Map.get(name)
    |> header_value()
  end

  defp header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if String.downcase(to_string(key)) == name, do: header_value(value)

      _other ->
        nil
    end)
  end

  defp header(_headers, _name), do: nil

  defp header_value([value | _rest]), do: value
  defp header_value(value), do: value

  defp strip_content_type_params(value) when is_binary(value) do
    value
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
  end

  defp strip_content_type_params(_value), do: nil
end
