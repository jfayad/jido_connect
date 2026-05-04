defmodule Jido.Connect.Slack.Client.ReactionsTest do
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
end
