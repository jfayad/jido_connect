defmodule Jido.Connect.DemoWeb.IntegrationControllerTest do
  use Jido.Connect.DemoWeb.ConnCase

  test "GET /health", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200) == %{"ok" => true}
  end

  test "GET /integrations lists github routes", %{conn: conn} do
    conn = get(conn, ~p"/integrations")

    assert %{"integrations" => integrations} = json_response(conn, 200)
    assert Enum.any?(integrations, &match?(%{"id" => "github", "status" => "available"}, &1))
    assert Enum.any?(integrations, &match?(%{"id" => "slack", "status" => "planned"}, &1))
  end

  test "setup complete stores manifest code", %{conn: conn} do
    secret_dir = tmp_dir()
    previous = System.get_env("JIDO_CONNECT_DEMO_SECRET_DIR")
    System.put_env("JIDO_CONNECT_DEMO_SECRET_DIR", secret_dir)

    on_exit(fn ->
      restore_env("JIDO_CONNECT_DEMO_SECRET_DIR", previous)
    end)

    conn = get(conn, ~p"/integrations/github/setup/complete?code=abc123")

    assert text_response(conn, 200) =~ "GitHub App manifest code captured"
    assert File.read!(Path.join(secret_dir, "github-app-code.txt")) == "abc123"
  end

  test "webhook validates signature when secret is configured", %{conn: conn} do
    secret_dir = tmp_dir()
    previous_secret = System.get_env("GITHUB_WEBHOOK_SECRET")
    previous_dir = System.get_env("JIDO_CONNECT_DEMO_SECRET_DIR")
    System.put_env("GITHUB_WEBHOOK_SECRET", "secret")
    System.put_env("JIDO_CONNECT_DEMO_SECRET_DIR", secret_dir)

    on_exit(fn ->
      restore_env("GITHUB_WEBHOOK_SECRET", previous_secret)
      restore_env("JIDO_CONNECT_DEMO_SECRET_DIR", previous_dir)
    end)

    body = ~s({"action":"opened"})
    signature = "sha256=" <> hmac("secret", body)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-github-delivery", "delivery-1")
      |> put_req_header("x-github-event", "issues")
      |> put_req_header("x-hub-signature-256", signature)
      |> post(~p"/integrations/github/webhook", body)

    assert %{"ok" => true, "event" => "issues"} = json_response(conn, 200)
    assert File.read!(Path.join(secret_dir, "github-webhook-delivery-1.json")) == body
  end

  defp hmac(secret, body) do
    :hmac
    |> :crypto.mac(:sha256, secret, body)
    |> Base.encode16(case: :lower)
  end

  defp tmp_dir do
    path =
      Path.join(System.tmp_dir!(), "jido-connect-demo-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(path)
    path
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
