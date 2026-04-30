defmodule Jido.Connect.Slack.ClientTest do
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

  test "list channels sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.list"

      assert %{
               "exclude_archived" => "true",
               "limit" => "100",
               "types" => "public_channel"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        channels: [
          %{
            id: "C123",
            name: "general",
            is_archived: false,
            is_private: false,
            is_member: true
          }
        ],
        response_metadata: %{next_cursor: "next"}
      })
    end)

    assert {:ok, %{channels: [%{id: "C123", name: "general"}], next_cursor: "next"}} =
             Client.list_channels(
               %{types: "public_channel", exclude_archived: true, limit: 100},
               "token"
             )
  end

  test "get thread replies sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.replies"

      assert %{
               "channel" => "C123",
               "cursor" => "page-1",
               "inclusive" => "true",
               "limit" => "50",
               "ts" => "1700000000.000100"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        messages: [
          %{
            type: "message",
            user: "U123",
            text: "Root",
            ts: "1700000000.000100",
            reply_count: 1,
            latest_reply: "1700000001.000200"
          },
          %{
            type: "message",
            user: "U456",
            text: "Reply",
            ts: "1700000001.000200",
            thread_ts: "1700000000.000100"
          }
        ],
        has_more: true,
        response_metadata: %{next_cursor: "page-2"}
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              thread_ts: "1700000000.000100",
              messages: [%{"text" => "Root"}, %{"text" => "Reply"}],
              next_cursor: "page-2",
              has_more: true
            }} =
             Client.get_thread_replies(
               %{
                 channel: "C123",
                 ts: "1700000000.000100",
                 limit: 50,
                 cursor: "page-1",
                 inclusive: true
               },
               "token"
             )
  end

  test "search messages sends expected request and normalizes pagination" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/search.messages"

      assert %{
               "query" => "deploy in:#general",
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
        query: "deploy in:#general",
        messages: %{
          matches: [
            %{
              type: "message",
              user: "U123",
              username: "ada",
              text: "deploy finished",
              ts: "1700000000.000100",
              channel: %{id: "C123", name: "general", is_private: false},
              permalink: "https://example.slack.com/archives/C123/p1700000000000100",
              team: "T123"
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
              query: "deploy in:#general",
              messages: [%{"text" => "deploy finished"}],
              total_count: 1,
              pagination: %{"page" => 2, "per_page" => 10, "total_count" => 1},
              paging: %{"page" => 2, "count" => 10, "total" => 1},
              next_cursor: "page-2"
            }} =
             Client.search_messages(
               %{
                 query: "deploy in:#general",
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

  test "list conversation members sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.members"

      assert %{
               "channel" => "C123",
               "cursor" => "page-1",
               "limit" => "100"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        members: ["U123", "U456"],
        response_metadata: %{next_cursor: "page-2"}
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              members: ["U123", "U456"],
              next_cursor: "page-2"
            }} =
             Client.list_conversation_members(
               %{channel: "C123", limit: 100, cursor: "page-1"},
               "token"
             )
  end

  test "get conversation info sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.info"

      assert %{
               "channel" => "C123",
               "include_locale" => "true"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "C123",
          name: "general",
          is_channel: true,
          is_private: false
        }
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              conversation: %{
                "id" => "C123",
                "name" => "general",
                "is_channel" => true
              }
            }} =
             Client.get_conversation_info(
               %{channel: "C123", include_locale: true},
               "token"
             )
  end

  test "create channel sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.create"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "name" => "project-updates",
               "is_private" => true,
               "team_id" => "T123"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "G123",
          name: "project-updates",
          is_archived: false,
          is_private: true,
          is_member: true,
          purpose: %{value: "raw value"}
        }
      })
    end)

    assert {:ok,
            %{
              channel: %{
                id: "G123",
                name: "project-updates",
                is_archived: false,
                is_private: true,
                is_member: true
              }
            }} =
             Client.create_channel(
               %{name: "project-updates", is_private: true, team_id: "T123"},
               "token"
             )
  end

  test "archive conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.archive"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123"} = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123"}} =
             Client.archive_conversation(%{channel: "C123"}, "token")
  end

  test "unarchive conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.unarchive"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123"} = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123"}} =
             Client.unarchive_conversation(%{channel: "C123"}, "token")
  end

  test "unarchive conversation normalizes Slack errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.unarchive"

      Req.Test.json(conn, %{ok: false, error: "not_archived"})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :slack,
              status: 200,
              reason: "not_archived"
            }} =
             Client.unarchive_conversation(%{channel: "C123"}, "token")
  end

  test "rename conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.rename"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123", "name" => "renamed-channel"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "C123",
          name: "renamed-channel",
          is_archived: false,
          is_private: false,
          is_member: true,
          purpose: %{value: "raw value"}
        }
      })
    end)

    assert {:ok,
            %{
              channel: %{
                id: "C123",
                name: "renamed-channel",
                is_archived: false,
                is_private: false,
                is_member: true
              }
            }} =
             Client.rename_conversation(%{channel: "C123", name: "renamed-channel"}, "token")
  end

  test "open conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.open"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "users" => "U123,U456",
               "return_im" => true,
               "prevent_creation" => false
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "G123",
          is_mpim: true,
          is_private: true,
          name: "mpdm-user-1--user-2-1",
          users: ["U123", "U456"],
          unread_count: 10
        }
      })
    end)

    assert {:ok,
            %{
              channel: "G123",
              conversation: %{
                id: "G123",
                is_mpim: true,
                is_private: true,
                name: "mpdm-user-1--user-2-1",
                users: ["U123", "U456"]
              }
            }} =
             Client.open_conversation(
               %{users: ["U123", "U456"], return_im: true, prevent_creation: false},
               "token"
             )
  end

  test "post message sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.postMessage"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123", "text" => "Hello"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: "C123",
        ts: "1700000000.000100",
        message: %{text: "Hello"}
      })
    end)

    assert {:ok, %{channel: "C123", ts: "1700000000.000100"}} =
             Client.post_message(%{channel: "C123", text: "Hello"}, "token")
  end

  test "post ephemeral sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.postEphemeral"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "user" => "U123",
               "text" => "Only you can see this"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        message_ts: "1700000000.000200"
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              user: "U123",
              message_ts: "1700000000.000200"
            }} =
             Client.post_ephemeral(
               %{channel: "C123", user: "U123", text: "Only you can see this"},
               "token"
             )
  end

  test "schedule message sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.scheduleMessage"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "text" => "Later",
               "post_at" => 1_700_000_600
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: "C123",
        scheduled_message_id: "Q123",
        post_at: "1700000600",
        message: %{text: "Later", type: "delayed_message"}
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              scheduled_message_id: "Q123",
              post_at: 1_700_000_600,
              message: %{"text" => "Later", "type" => "delayed_message"}
            }} =
             Client.schedule_message(
               %{channel: "C123", text: "Later", post_at: 1_700_000_600},
               "token"
             )
  end

  test "delete scheduled message sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.deleteScheduledMessage"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "scheduled_message_id" => "Q123"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123", scheduled_message_id: "Q123"}} =
             Client.delete_scheduled_message(
               %{channel: "C123", scheduled_message_id: "Q123"},
               "token"
             )
  end

  test "update message sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.update"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "ts" => "1700000000.000100",
               "text" => "Updated",
               "blocks" => [%{"type" => "section"}]
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: "C123",
        ts: "1700000000.000100",
        message: %{text: "Updated"}
      })
    end)

    assert {:ok, %{channel: "C123", ts: "1700000000.000100"}} =
             Client.update_message(
               %{
                 channel: "C123",
                 ts: "1700000000.000100",
                 text: "Updated",
                 blocks: [%{type: "section"}]
               },
               "token"
             )
  end

  test "delete message sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.delete"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "ts" => "1700000000.000100"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: "C123",
        ts: "1700000000.000100"
      })
    end)

    assert {:ok, %{channel: "C123", ts: "1700000000.000100"}} =
             Client.delete_message(%{channel: "C123", ts: "1700000000.000100"}, "token")
  end

  test "add reaction sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/reactions.add"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "timestamp" => "1700000000.000100",
               "name" => "thumbsup"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"}} =
             Client.add_reaction(
               %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"},
               "token"
             )
  end

  test "remove reaction sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/reactions.remove"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "timestamp" => "1700000000.000100",
               "name" => "thumbsup"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"}} =
             Client.remove_reaction(
               %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"},
               "token"
             )
  end

  test "get reactions sends expected message target request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/reactions.get"

      assert %{
               "channel" => "C123",
               "timestamp" => "1700000000.000100",
               "full" => "true"
             } = Plug.Conn.Query.decode(conn.query_string)

      Req.Test.json(conn, %{
        ok: true,
        type: "message",
        channel: "C123",
        message: %{
          type: "message",
          user: "U123",
          text: "Hello",
          ts: "1700000000.000100",
          reactions: [%{name: "thumbsup", count: 1, users: ["U123"]}]
        }
      })
    end)

    assert {:ok,
            %{
              type: "message",
              channel: "C123",
              timestamp: "1700000000.000100",
              message: %{"text" => "Hello"},
              reactions: [%{"name" => "thumbsup", "count" => 1, "users" => ["U123"]}]
            }} =
             Client.get_reactions(
               %{channel: "C123", timestamp: "1700000000.000100", full: true},
               "token"
             )
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
              details: %{body: %{"ok" => true, "file_id" => "F123"}}
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
              details: %{body: %{"ok" => true, "files" => %{"id" => "F123"}}}
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
              details: %{body: %{"ok" => true, "files" => %{"id" => "F123"}}}
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

  test "list users sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/users.list"

      assert %{
               "include_locale" => "true",
               "limit" => "100",
               "team_id" => "T123"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        members: [
          %{
            id: "U123",
            team_id: "T123",
            name: "ada",
            real_name: "Ada Lovelace",
            deleted: false,
            is_bot: false,
            is_app_user: false,
            profile: %{email: "ada@example.com"}
          }
        ],
        response_metadata: %{next_cursor: "next"}
      })
    end)

    assert {:ok,
            %{
              users: [
                %{
                  id: "U123",
                  team_id: "T123",
                  name: "ada",
                  real_name: "Ada Lovelace",
                  profile: %{"email" => "ada@example.com"}
                }
              ],
              next_cursor: "next"
            }} =
             Client.list_users(%{limit: 100, team_id: "T123", include_locale: true}, "token")
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

  test "lookup user by email normalizes Slack users_not_found" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/users.lookupByEmail"

      Req.Test.json(conn, %{ok: false, error: "users_not_found"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              status: 404,
              reason: :not_found,
              message: "Slack user was not found"
            }} = Client.lookup_user_by_email(%{email: "missing@example.com"}, "token")
  end

  test "lookup user by email normalizes malformed successful responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/users.lookupByEmail"

      Req.Test.json(conn, %{ok: true, user: nil})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body: %{"ok" => true, "user" => nil}}
            }} = Client.lookup_user_by_email(%{email: "ada@example.com"}, "token")
  end

  test "auth test returns successful response maps" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/auth.test"

      Req.Test.json(conn, %{ok: true, team_id: "T123", user_id: "U123"})
    end)

    assert {:ok, %{"team_id" => "T123", "user_id" => "U123"}} = Client.auth_test("token")
  end

  test "team info sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/team.info"
      assert %{"team" => "T123"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        team: %{
          id: "T123",
          name: "Demo",
          domain: "demo",
          enterprise_id: "E123",
          enterprise_name: "Example Enterprise"
        }
      })
    end)

    assert {:ok,
            %{
              team: %{
                "id" => "T123",
                "name" => "Demo",
                "enterprise_id" => "E123"
              }
            }} = Client.team_info(%{team_id: "T123"}, "token")
  end

  test "normalizes Slack API errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{ok: false, error: "invalid_auth"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: "invalid_auth",
              status: 200,
              details: %{body: %{"ok" => false, "error" => "invalid_auth"}}
            }} =
             Client.auth_test("bad-token")
  end

  test "normalizes non-API HTTP errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.json(%{error: "server_error"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :http_error,
              status: 500,
              details: %{body: %{"error" => "server_error"}}
            }} = Client.auth_test("token")
  end

  test "normalizes malformed successful responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{ok: true, channels: %{id: "C123"}})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body: %{"ok" => true, "channels" => %{"id" => "C123"}}}
            }} =
             Client.list_channels(%{types: "public_channel"}, "token")
  end
end
