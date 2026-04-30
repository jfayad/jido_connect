defmodule Jido.Connect.Slack.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_slack, :slack_req_options)
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
