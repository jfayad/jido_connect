defmodule Jido.Connect.Google.Drive.Client.Params do
  @moduledoc "Google Drive request parameter helpers."

  alias Jido.Connect.Data

  @default_file_fields [
    "id",
    "name",
    "mimeType",
    "description",
    "webViewLink",
    "webContentLink",
    "iconLink",
    "thumbnailLink",
    "size",
    "md5Checksum",
    "createdTime",
    "modifiedTime",
    "parents",
    "owners",
    "shared",
    "trashed",
    "starred",
    "driveId"
  ]

  @doc "Default file metadata fields used by read actions."
  def default_file_fields, do: Enum.join(@default_file_fields, ",")

  @doc "Builds query params for `files.list`."
  def list_files_params(params) do
    %{
      q: Data.get(params, :query),
      pageSize: Data.get(params, :page_size, 25),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, list_fields()),
      orderBy: Data.get(params, :order_by),
      spaces: Data.get(params, :spaces, "drive"),
      corpora: Data.get(params, :corpora),
      driveId: Data.get(params, :drive_id),
      includeItemsFromAllDrives: Data.get(params, :include_items_from_all_drives),
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `files.get`."
  def get_file_params(params) do
    %{
      fields: Data.get(params, :fields, default_file_fields()),
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  defp list_fields, do: "nextPageToken,files(#{default_file_fields()})"
end
