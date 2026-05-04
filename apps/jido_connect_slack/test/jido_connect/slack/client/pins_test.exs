defmodule Jido.Connect.Slack.Client.PinsTest do
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

  test "add pin sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/pins.add"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "timestamp" => "1700000000.000100"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{type: "message", channel: "C123", timestamp: "1700000000.000100"}} =
             Client.add_pin(%{channel: "C123", timestamp: "1700000000.000100"}, "token")
  end

  test "remove pin sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/pins.remove"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "timestamp" => "1700000000.000100"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{type: "message", channel: "C123", timestamp: "1700000000.000100"}} =
             Client.remove_pin(%{channel: "C123", timestamp: "1700000000.000100"}, "token")
  end

  test "list pins sends expected request and normalizes pinned items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/pins.list"
      assert %{"channel" => "C123"} = Plug.Conn.Query.decode(conn.query_string)

      Req.Test.json(conn, %{
        ok: true,
        items: [
          %{
            "type" => "message",
            "channel" => "C123",
            "created" => 1_700_000_001,
            "created_by" => "U123",
            "message" => %{
              "type" => "message",
              "channel" => "C123",
              "text" => "Pinned",
              "ts" => "1700000000.000100"
            }
          },
          %{
            "type" => "file_comment",
            "created" => 1_700_000_002,
            "created_by" => "U456",
            "file" => %{"id" => "F123", "name" => "report.txt"},
            "comment" => %{"id" => "Fc123", "comment" => "Looks good"}
          }
        ]
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              items: [
                %{
                  type: "message",
                  channel: "C123",
                  timestamp: "1700000000.000100",
                  created: 1_700_000_001,
                  created_by: "U123",
                  message: %{"text" => "Pinned"}
                },
                %{
                  type: "file_comment",
                  created: 1_700_000_002,
                  created_by: "U456",
                  file: %{"id" => "F123"},
                  file_comment: %{"id" => "Fc123"}
                }
              ]
            }} = Client.list_pins(%{channel: "C123"}, "token")
  end
end
