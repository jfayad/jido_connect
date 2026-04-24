defmodule Jido.Connect.GitHub.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
  end

  test "list issues sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/issues"
      assert conn.query_string == "state=open"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{number: 1, html_url: "https://github.test/1", title: "Issue", state: "open"}
      ])
    end)

    assert {:ok, [%{number: 1, url: "https://github.test/1"}]} =
             Client.list_issues("org/repo", "open", "token")
  end

  test "create issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues"

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "open"
      })
    end)

    assert {:ok, %{number: 2, title: "Bug"}} =
             Client.create_issue("org/repo", %{title: "Bug"}, "token")
  end

  test "normalizes error responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{message: "Resource not accessible"})
    end)

    assert {:error, {:github_http_error, 403, "Resource not accessible"}} =
             Client.fetch_authenticated_user("token")
  end
end
