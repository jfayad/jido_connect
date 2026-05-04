defmodule Jido.Connect.Slack.Client.ResponseTest do
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

  test "normalizes malformed successful responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{ok: true, channels: %{id: "C123"}})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["channels", "ok"]}}
            }} =
             Client.list_channels(%{types: "public_channel"}, "token")
  end
end
