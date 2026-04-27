defmodule Jido.Connect.DemoWeb.PageControllerTest do
  use Jido.Connect.DemoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Jido Connect"
  end

  test "GET / searches local catalog cards", %{conn: conn} do
    conn = get(conn, ~p"/?q=issue")
    html = html_response(conn, 200)

    assert html =~ "GitHub"
    refute html =~ "Slack Integration"
  end
end
