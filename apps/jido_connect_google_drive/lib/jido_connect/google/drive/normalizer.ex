defmodule Jido.Connect.Google.Drive.Normalizer do
  @moduledoc "Normalizes Google Drive API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Drive.{Change, File, Folder, Permission}

  @folder_mime_type "application/vnd.google-apps.folder"

  @doc "Normalizes a Google Drive file payload."
  @spec file(map()) :: {:ok, File.t()} | {:error, term()}
  def file(payload) when is_map(payload) do
    %{
      file_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      mime_type: Data.get(payload, "mimeType"),
      description: Data.get(payload, "description"),
      web_view_link: Data.get(payload, "webViewLink"),
      web_content_link: Data.get(payload, "webContentLink"),
      icon_link: Data.get(payload, "iconLink"),
      thumbnail_link: Data.get(payload, "thumbnailLink"),
      size: normalize_integer(Data.get(payload, "size")),
      md5_checksum: Data.get(payload, "md5Checksum"),
      created_time: Data.get(payload, "createdTime"),
      modified_time: Data.get(payload, "modifiedTime"),
      parents: Data.get(payload, "parents", []),
      owners: Data.get(payload, "owners", []),
      shared?: Data.get(payload, "shared", false),
      trashed?: Data.get(payload, "trashed", false),
      starred?: Data.get(payload, "starred", false),
      drive_id: Data.get(payload, "driveId")
    }
    |> Data.compact()
    |> File.new()
  end

  @doc "Normalizes a Google Drive folder payload."
  @spec folder(map()) :: {:ok, Folder.t()} | {:error, term()}
  def folder(payload) when is_map(payload) do
    %{
      folder_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      web_view_link: Data.get(payload, "webViewLink"),
      created_time: Data.get(payload, "createdTime"),
      modified_time: Data.get(payload, "modifiedTime"),
      parents: Data.get(payload, "parents", []),
      trashed?: Data.get(payload, "trashed", false),
      shared?: Data.get(payload, "shared", false),
      drive_id: Data.get(payload, "driveId")
    }
    |> Data.compact()
    |> Folder.new()
  end

  @doc "Normalizes a Google Drive permission payload."
  @spec permission(map()) :: {:ok, Permission.t()} | {:error, term()}
  def permission(payload) when is_map(payload) do
    %{
      permission_id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      role: Data.get(payload, "role"),
      email_address: Data.get(payload, "emailAddress"),
      domain: Data.get(payload, "domain"),
      display_name: Data.get(payload, "displayName"),
      allow_file_discovery?: Data.get(payload, "allowFileDiscovery"),
      deleted?: Data.get(payload, "deleted", false),
      expiration_time: Data.get(payload, "expirationTime")
    }
    |> Data.compact()
    |> Permission.new()
  end

  @doc "Normalizes a Google Drive change payload."
  @spec change(map()) :: {:ok, Change.t()} | {:error, term()}
  def change(payload) when is_map(payload) do
    file = normalize_change_file(Data.get(payload, "file"))

    %{
      change_id: normalize_string(Data.get(payload, "changeId")),
      file_id: Data.get(payload, "fileId"),
      file: file,
      removed?: Data.get(payload, "removed", false),
      time: Data.get(payload, "time"),
      drive_id: Data.get(payload, "driveId"),
      change_type: Data.get(payload, "changeType")
    }
    |> Data.compact()
    |> Change.new()
  end

  @doc "Returns true when a Drive payload is a folder."
  @spec folder?(map()) :: boolean()
  def folder?(payload) when is_map(payload),
    do: Data.get(payload, "mimeType") == @folder_mime_type

  def folder?(_payload), do: false

  defp normalize_change_file(%{} = payload) do
    case file(payload) do
      {:ok, file} -> file
      {:error, error} -> raise error
    end
  end

  defp normalize_change_file(_payload), do: nil

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)
end
