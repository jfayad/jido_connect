defmodule Jido.Connect.Google.Drive.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Drive.{Client, File, Folder, Permission}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_drive,
      :google_drive_api_base_url,
      "https://drive.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_drive, :google_drive_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "lists files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
      assert conn.query_params["q"] == "mimeType = 'application/pdf'"
      assert conn.query_params["pageSize"] == "10"
      assert conn.query_params["spaces"] == "drive"

      Req.Test.json(conn, %{
        "files" => [
          %{
            "id" => "file123",
            "name" => "Budget.pdf",
            "mimeType" => "application/pdf",
            "parents" => ["folder123"]
          }
        ],
        "nextPageToken" => "next"
      })
    end)

    assert {:ok, %{files: [%File{} = file], next_page_token: "next"}} =
             Client.list_files(
               %{query: "mimeType = 'application/pdf'", page_size: 10, spaces: "drive"},
               "token"
             )

    assert file.file_id == "file123"
    assert file.name == "Budget.pdf"
  end

  test "gets file metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["fields"] =~ "id,name,mimeType"

      Req.Test.json(conn, %{
        "id" => "file123",
        "name" => "Budget.pdf",
        "mimeType" => "application/pdf"
      })
    end)

    assert {:ok, %File{} = file} =
             Client.get_file(%{file_id: "file123", supports_all_drives: false}, "token")

    assert file.file_id == "file123"
    assert file.name == "Budget.pdf"
  end

  test "creates file metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Notes",
               "mimeType" => "text/plain",
               "parents" => ["folder123"]
             }

      Req.Test.json(conn, %{
        "id" => "created123",
        "name" => "Notes",
        "mimeType" => "text/plain",
        "parents" => ["folder123"]
      })
    end)

    assert {:ok, %File{} = file} =
             Client.create_file(
               %{name: "Notes", mime_type: "text/plain", parents: ["folder123"]},
               "token"
             )

    assert file.file_id == "created123"
    assert file.parents == ["folder123"]
  end

  test "creates folders" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Reports",
               "mimeType" => "application/vnd.google-apps.folder",
               "parents" => ["root"]
             }

      Req.Test.json(conn, %{
        "id" => "folder456",
        "name" => "Reports",
        "mimeType" => "application/vnd.google-apps.folder",
        "parents" => ["root"]
      })
    end)

    assert {:ok, %Folder{} = folder} =
             Client.create_folder(%{name: "Reports", parents: ["root"]}, "token")

    assert folder.folder_id == "folder456"
    assert folder.parents == ["root"]
  end

  test "copies files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files/file123/copy"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Budget Copy.pdf",
               "parents" => ["folder123"]
             }

      Req.Test.json(conn, %{
        "id" => "copy123",
        "name" => "Budget Copy.pdf",
        "mimeType" => "application/pdf",
        "parents" => ["folder123"]
      })
    end)

    assert {:ok, %File{} = file} =
             Client.copy_file(
               %{file_id: "file123", name: "Budget Copy.pdf", parents: ["folder123"]},
               "token"
             )

    assert file.file_id == "copy123"
    assert file.name == "Budget Copy.pdf"
  end

  test "updates files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["addParents"] == "folder456"
      assert conn.query_params["removeParents"] == "folder123"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"name" => "Renamed.pdf"}

      Req.Test.json(conn, %{
        "id" => "file123",
        "name" => "Renamed.pdf",
        "mimeType" => "application/pdf",
        "parents" => ["folder456"]
      })
    end)

    assert {:ok, %File{} = file} =
             Client.update_file(
               %{
                 file_id: "file123",
                 name: "Renamed.pdf",
                 add_parents: "folder456",
                 remove_parents: "folder123"
               },
               "token"
             )

    assert file.name == "Renamed.pdf"
    assert file.parents == ["folder456"]
  end

  test "exports Google Workspace files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/export"
      assert conn.query_params["mimeType"] == "text/csv"
      assert Plug.Conn.get_req_header(conn, "accept") == ["text/csv"]

      conn
      |> Plug.Conn.put_resp_content_type("text/csv")
      |> Plug.Conn.resp(200, "name,total\nBudget,10\n")
    end)

    assert {:ok, content} =
             Client.export_file(%{file_id: "file123", mime_type: "text/csv"}, "token")

    assert content.file_id == "file123"
    assert content.mime_type == "text/csv"
    assert content.content == "name,total\nBudget,10\n"
    assert content.encoding == "utf-8"
    assert content.binary == false
  end

  test "downloads binary files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["alt"] == "media"
      assert conn.query_params["supportsAllDrives"] == "true"
      assert Plug.Conn.get_req_header(conn, "accept") == ["*/*"]

      conn
      |> Plug.Conn.put_resp_content_type("application/pdf")
      |> Plug.Conn.resp(200, <<0, 1, 2>>)
    end)

    assert {:ok, content} =
             Client.download_file(%{file_id: "file123", supports_all_drives: true}, "token")

    assert content.file_id == "file123"
    assert content.mime_type == "application/pdf"
    assert content.content_base64 == "AAEC"
    assert content.encoding == "base64"
    assert content.binary == true
  end

  test "deletes files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["supportsAllDrives"] == "true"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{file_id: "file123", deleted?: true}} =
             Client.delete_file(%{file_id: "file123", supports_all_drives: true}, "token")
  end

  test "lists file permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/permissions"
      assert conn.query_params["pageSize"] == "50"
      assert conn.query_params["supportsAllDrives"] == "true"
      assert conn.query_params["useDomainAdminAccess"] == "false"
      assert conn.query_params["fields"] =~ "permissions(id,type,role"

      Req.Test.json(conn, %{
        "permissions" => [
          %{
            "id" => "perm123",
            "type" => "user",
            "role" => "reader",
            "emailAddress" => "reader@example.com"
          }
        ],
        "nextPageToken" => "next-perm"
      })
    end)

    assert {:ok, %{permissions: [%Permission{} = permission], next_page_token: "next-perm"}} =
             Client.list_permissions(
               %{
                 file_id: "file123",
                 page_size: 50,
                 supports_all_drives: true,
                 use_domain_admin_access: false
               },
               "token"
             )

    assert permission.permission_id == "perm123"
    assert permission.email_address == "reader@example.com"
  end

  test "creates file permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files/file123/permissions"
      assert conn.query_params["sendNotificationEmail"] == "false"
      assert conn.query_params["transferOwnership"] == "false"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "type" => "user",
               "role" => "reader",
               "emailAddress" => "reader@example.com"
             }

      Req.Test.json(conn, %{
        "id" => "perm456",
        "type" => "user",
        "role" => "reader",
        "emailAddress" => "reader@example.com"
      })
    end)

    assert {:ok, %Permission{} = permission} =
             Client.create_permission(
               %{
                 file_id: "file123",
                 type: "user",
                 role: "reader",
                 email_address: "reader@example.com",
                 send_notification_email: false,
                 transfer_ownership: false
               },
               "token"
             )

    assert permission.permission_id == "perm456"
    assert permission.role == "reader"
  end
end
