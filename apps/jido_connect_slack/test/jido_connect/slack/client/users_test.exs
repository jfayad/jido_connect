defmodule Jido.Connect.Slack.Client.UsersTest do
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
              details: %{body_summary: %{type: :map, keys: ["ok", "user"]}}
            }} = Client.lookup_user_by_email(%{email: "ada@example.com"}, "token")
  end
end
