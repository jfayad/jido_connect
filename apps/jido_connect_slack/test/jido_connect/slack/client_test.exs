defmodule Jido.Connect.Slack.ClientTest do
  use ExUnit.Case, async: false

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

  test "normalizes Slack API errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{ok: false, error: "invalid_auth"})
    end)

    assert {:error,
            {:slack_api_error, "invalid_auth", 200, %{"ok" => false, "error" => "invalid_auth"}}} =
             Client.auth_test("bad-token")
  end
end
