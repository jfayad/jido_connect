defmodule Jido.Connect.Slack.Client.ConversationsTest do
  use ExUnit.Case, async: false

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

  test "invite conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.invite"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123", "users" => "U123,U456", "force" => true} =
               Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "C123",
          name: "project-updates",
          is_archived: false,
          is_private: false,
          is_member: true
        }
      })
    end)

    assert {:ok,
            %{
              channel: %{
                id: "C123",
                name: "project-updates",
                is_archived: false,
                is_private: false,
                is_member: true
              },
              invited_users: ["U123", "U456"],
              failed_users: [],
              partial_failure: false
            }} =
             Client.invite_conversation(
               %{channel: "C123", users: ["U123", "U456"], force: true},
               "token"
             )
  end

  test "invite conversation normalizes partial failures when force is enabled" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.invite"

      Req.Test.json(conn, %{
        ok: false,
        error: "user_not_found",
        errors: [
          %{user: "U404", ok: false, error: "user_not_found"}
        ]
      })
    end)

    assert {:ok,
            %{
              channel: %{id: "C123"},
              invited_users: ["U123"],
              failed_users: [%{user: "U404", ok: false, error: "user_not_found"}],
              partial_failure: true
            }} =
             Client.invite_conversation(
               %{channel: "C123", users: ["U123", "U404"], force: true},
               "token"
             )
  end

  test "invite conversation returns provider error for partial failures without force" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.invite"

      Req.Test.json(conn, %{
        ok: false,
        error: "user_not_found",
        errors: [
          %{user: "U404", ok: false, error: "user_not_found"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              reason: "user_not_found",
              details: %{failed_users: [%{user: "U404", ok: false, error: "user_not_found"}]}
            }} =
             Client.invite_conversation(
               %{channel: "C123", users: ["U123", "U404"], force: false},
               "token"
             )
  end

  test "kick conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.kick"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123", "user" => "U123"} = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123", user: "U123"}} =
             Client.kick_conversation(%{channel: "C123", user: "U123"}, "token")
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
end
