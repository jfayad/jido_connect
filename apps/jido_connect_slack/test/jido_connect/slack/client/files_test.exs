defmodule Jido.Connect.Slack.Client.FilesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})

    Application.put_env(:jido_connect_slack, :slack_upload_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_slack, :slack_req_options)
      Application.delete_env(:jido_connect_slack, :slack_upload_req_options)
    end)
  end

  test "get reactions sends expected file target request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/reactions.get"

      assert %{"file" => "F123"} = Plug.Conn.Query.decode(conn.query_string)

      Req.Test.json(conn, %{
        ok: true,
        type: "file",
        file: %{
          id: "F123",
          name: "report.txt",
          reactions: [%{name: "eyes", count: 2, users: ["U123", "U456"]}]
        }
      })
    end)

    assert {:ok,
            %{
              type: "file",
              file_id: "F123",
              file: %{"name" => "report.txt"},
              reactions: [%{"name" => "eyes", "count" => 2, "users" => ["U123", "U456"]}]
            }} = Client.get_reactions(%{file: "F123"}, "token")
  end

  test "upload file uses external upload flow" do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/api/files.getUploadURLExternal" ->
          assert conn.method == "POST"

          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert %{
                   "filename" => "report.txt",
                   "length" => 10,
                   "alt_txt" => "Report text",
                   "snippet_type" => "text"
                 } = Jason.decode!(body)

          assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

          Req.Test.json(conn, %{
            ok: true,
            upload_url: "https://uploads.slack.test/upload/123",
            file_id: "F123"
          })

        "/upload/123" ->
          assert conn.method == "POST"
          assert ["application/octet-stream"] = Plug.Conn.get_req_header(conn, "content-type")

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body == "Hello file"

          Req.Test.text(conn, "OK")

        "/api/files.completeUploadExternal" ->
          assert conn.method == "POST"

          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert %{
                   "channel_id" => "C123",
                   "initial_comment" => "Here is the report",
                   "thread_ts" => "1700000000.000100",
                   "files" => [%{"id" => "F123", "title" => "Report"}]
                 } = Jason.decode!(body)

          assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

          Req.Test.json(conn, %{
            ok: true,
            files: [%{id: "F123", title: "Report"}]
          })
      end
    end)

    assert {:ok, %{file_id: "F123", files: [%{"id" => "F123", "title" => "Report"}]}} =
             Client.upload_file(
               %{
                 channel_id: "C123",
                 filename: "report.txt",
                 content: "Hello file",
                 title: "Report",
                 initial_comment: "Here is the report",
                 thread_ts: "1700000000.000100",
                 alt_txt: "Report text",
                 snippet_type: "text"
               },
               "token"
             )
  end

  test "search files sends expected request and normalizes pagination" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/search.files"

      assert %{
               "query" => "report in:#general",
               "sort" => "timestamp",
               "sort_dir" => "desc",
               "count" => "10",
               "page" => "2",
               "highlight" => "true",
               "cursor" => "page-1"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        query: "report in:#general",
        files: %{
          matches: [
            %{
              id: "F123",
              name: "report.pdf",
              title: "Report",
              mimetype: "application/pdf",
              permalink: "https://example.slack.com/files/U123/F123/report.pdf"
            }
          ],
          pagination: %{page: 2, per_page: 10, total_count: 1},
          paging: %{page: 2, count: 10, total: 1},
          total: 1
        },
        response_metadata: %{next_cursor: "page-2"}
      })
    end)

    assert {:ok,
            %{
              query: "report in:#general",
              files: [%{"name" => "report.pdf"}],
              total_count: 1,
              pagination: %{"page" => 2, "per_page" => 10, "total_count" => 1},
              paging: %{"page" => 2, "count" => 10, "total" => 1},
              next_cursor: "page-2"
            }} =
             Client.search_files(
               %{
                 query: "report in:#general",
                 sort: "timestamp",
                 sort_dir: "desc",
                 count: 10,
                 page: 2,
                 highlight: true,
                 cursor: "page-1"
               },
               "token"
             )
  end

  test "search files normalizes malformed responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/search.files"

      Req.Test.json(conn, %{ok: true, files: %{matches: %{id: "F123"}}})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["files", "ok"]}}
            }} =
             Client.search_files(%{query: "report"}, "token")
  end

  test "upload file normalizes malformed upload URL responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/files.getUploadURLExternal"

      Req.Test.json(conn, %{ok: true, file_id: "F123"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["file_id", "ok"]}}
            }} =
             Client.upload_file(
               %{channel_id: "C123", filename: "report.txt", content: "Hello file"},
               "token"
             )
  end

  test "upload file normalizes malformed complete upload responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/api/files.getUploadURLExternal" ->
          Req.Test.json(conn, %{
            ok: true,
            upload_url: "https://uploads.slack.test/upload/123",
            file_id: "F123"
          })

        "/upload/123" ->
          Req.Test.text(conn, "OK")

        "/api/files.completeUploadExternal" ->
          Req.Test.json(conn, %{ok: true, files: %{"id" => "F123"}})
      end
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["files", "ok"]}}
            }} =
             Client.upload_file(
               %{channel_id: "C123", filename: "report.txt", content: "Hello file"},
               "token"
             )
  end

  test "share file sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/files.completeUploadExternal"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channels" => "C123,C456",
               "initial_comment" => "Here is the report",
               "thread_ts" => "1700000000.000100",
               "files" => [%{"id" => "F123", "title" => "Report"}]
             } = Jason.decode!(body)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        files: [%{id: "F123", title: "Report"}]
      })
    end)

    assert {:ok, %{file_id: "F123", files: [%{"id" => "F123", "title" => "Report"}]}} =
             Client.share_file(
               %{
                 file_id: "F123",
                 channels: "C123,C456",
                 title: "Report",
                 initial_comment: "Here is the report",
                 thread_ts: "1700000000.000100"
               },
               "token"
             )
  end

  test "share file normalizes malformed responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/files.completeUploadExternal"

      Req.Test.json(conn, %{ok: true, files: %{"id" => "F123"}})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["files", "ok"]}}
            }} =
             Client.share_file(%{file_id: "F123", channels: "C123"}, "token")
  end

  test "delete file sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/files.delete"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"file" => "F123"} = Jason.decode!(body)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{file_id: "F123"}} =
             Client.delete_file(%{file_id: "F123"}, "token")
  end

  test "user info sends expected request and normalizes profile" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/users.info"

      assert %{
               "include_locale" => "true",
               "user" => "B123"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        user: %{
          id: "B123",
          team_id: "T123",
          name: "build-bot",
          real_name: "Build Bot",
          deleted: false,
          is_bot: true,
          is_app_user: false,
          profile: %{
            bot_id: "B999",
            display_name: "build-bot",
            real_name: "Build Bot",
            unknown_profile_field: "ignored"
          },
          unknown_user_field: "ignored"
        }
      })
    end)

    assert {:ok,
            %{
              user: %{
                id: "B123",
                team_id: "T123",
                name: "build-bot",
                real_name: "Build Bot",
                deleted: false,
                is_bot: true,
                is_app_user: false,
                profile: %{
                  bot_id: "B999",
                  display_name: "build-bot",
                  real_name: "Build Bot"
                }
              }
            }} = Client.user_info(%{user: "B123", include_locale: true}, "token")
  end

  test "lookup user by email sends expected request and normalizes profile" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/users.lookupByEmail"
      assert %{"email" => "ada@example.com"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        user: %{
          id: "U123",
          team_id: "T123",
          name: "ada",
          real_name: "Ada Lovelace",
          deleted: false,
          is_bot: false,
          is_app_user: false,
          profile: %{
            email: "ada@example.com",
            display_name: "ada",
            real_name: "Ada Lovelace",
            unknown_profile_field: "ignored"
          },
          unknown_user_field: "ignored"
        }
      })
    end)

    assert {:ok,
            %{
              user: %{
                id: "U123",
                team_id: "T123",
                name: "ada",
                real_name: "Ada Lovelace",
                deleted: false,
                is_bot: false,
                is_app_user: false,
                profile: %{
                  email: "ada@example.com",
                  display_name: "ada",
                  real_name: "Ada Lovelace"
                }
              }
            }} = Client.lookup_user_by_email(%{email: "ada@example.com"}, "token")
  end
end
