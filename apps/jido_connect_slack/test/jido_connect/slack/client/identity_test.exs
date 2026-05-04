defmodule Jido.Connect.Slack.Client.IdentityTest do
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
              details: %{body_summary: %{type: :map, keys: ["error", "ok"]}}
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
              details: %{body_summary: %{type: :map, keys: ["error"]}}
            }} = Client.auth_test("token")
  end
end
