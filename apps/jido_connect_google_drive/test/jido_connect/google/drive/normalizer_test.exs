defmodule Jido.Connect.Google.Drive.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive.{Change, File, Folder, Normalizer, Permission}

  test "normalizes file payloads" do
    assert {:ok, %File{} = file} =
             Normalizer.file(%{
               "id" => "file123",
               "name" => "Budget.pdf",
               "mimeType" => "application/pdf",
               "description" => "Quarterly budget",
               "webViewLink" => "https://drive.google.com/file/d/file123/view",
               "size" => "1024",
               "createdTime" => "2026-05-01T10:00:00Z",
               "modifiedTime" => "2026-05-02T10:00:00Z",
               "parents" => ["folder123"],
               "owners" => [%{"emailAddress" => "owner@example.com"}],
               "shared" => true
             })

    assert file.file_id == "file123"
    assert file.name == "Budget.pdf"
    assert file.size == 1024
    assert file.parents == ["folder123"]
    assert file.shared?
  end

  test "normalizes folder payloads" do
    assert {:ok, %Folder{} = folder} =
             Normalizer.folder(%{
               "id" => "folder123",
               "name" => "Reports",
               "mimeType" => "application/vnd.google-apps.folder",
               "webViewLink" => "https://drive.google.com/drive/folders/folder123",
               "parents" => ["root"],
               "shared" => false
             })

    assert folder.folder_id == "folder123"
    assert folder.name == "Reports"
    assert folder.parents == ["root"]
    refute folder.shared?
  end

  test "normalizes permission payloads" do
    assert {:ok, %Permission{} = permission} =
             Normalizer.permission(%{
               "id" => "perm123",
               "type" => "user",
               "role" => "reader",
               "emailAddress" => "reader@example.com",
               "displayName" => "Reader",
               "allowFileDiscovery" => false
             })

    assert permission.permission_id == "perm123"
    assert permission.type == "user"
    assert permission.role == "reader"
    assert permission.email_address == "reader@example.com"
    refute permission.allow_file_discovery?
  end

  test "normalizes change payloads with embedded files" do
    assert {:ok, %Change{} = change} =
             Normalizer.change(%{
               "changeId" => 42,
               "fileId" => "file123",
               "removed" => false,
               "time" => "2026-05-02T10:00:00Z",
               "file" => %{
                 "id" => "file123",
                 "name" => "Budget.pdf",
                 "mimeType" => "application/pdf"
               }
             })

    assert change.change_id == "42"
    assert change.file_id == "file123"
    assert change.file.name == "Budget.pdf"
    refute change.removed?
  end

  test "detects folder payloads" do
    assert Normalizer.folder?(%{"mimeType" => "application/vnd.google-apps.folder"})
    refute Normalizer.folder?(%{"mimeType" => "application/pdf"})
  end
end
