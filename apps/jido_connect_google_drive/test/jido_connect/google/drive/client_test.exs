defmodule Jido.Connect.Google.Drive.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Drive.{Client, File}

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
end
