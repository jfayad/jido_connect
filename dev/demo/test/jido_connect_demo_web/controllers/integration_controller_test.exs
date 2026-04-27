defmodule Jido.Connect.DemoWeb.IntegrationControllerTest do
  use Jido.Connect.DemoWeb.ConnCase

  alias Jido.Connect.Demo.{GitHubRuntime, SlackRuntime, Store}

  defmodule FakeGitHubClient do
    def list_issues("org/repo", "open", "token") do
      {:ok, [%{number: 1, url: "https://github.test/1", title: "First", state: "open"}]}
    end

    def create_issue("org/repo", %{title: "Bug", body: "", labels: []}, "token") do
      {:ok, %{number: 2, url: "https://github.test/2", title: "Bug", state: "open"}}
    end

    def list_new_issues("org/repo", nil, "token") do
      {:ok,
       [
         %{
           number: 3,
           url: "https://github.test/3",
           title: "Third",
           updated_at: "2026-04-24T20:00:00Z"
         }
       ]}
    end
  end

  defmodule FakeSlackClient do
    def auth_test("xoxb-test") do
      {:ok,
       %{
         "team" => "Demo Workspace",
         "team_id" => "T123",
         "url" => "https://demo.slack.com/",
         "user" => "jido_connect",
         "user_id" => "U123",
         "bot_id" => "B123"
       }}
    end

    def list_channels(%{types: "public_channel"}, "xoxb-test") do
      {:ok,
       %{
         channels: [
           %{
             id: "C123",
             name: "general",
             is_archived: false,
             is_private: false,
             is_member: true
           }
         ],
         next_cursor: ""
       }}
    end

    def post_message(%{channel: "C123", text: "Hello"}, "xoxb-test") do
      {:ok, %{channel: "C123", ts: "1700000000.000100", message: %{text: "Hello"}}}
    end
  end

  setup do
    Store.reset!()
    previous_slack_client = Application.get_env(:jido_connect_demo, :slack_client)
    previous_slack_bot_token = System.get_env("SLACK_BOT_TOKEN")

    Application.put_env(:jido_connect_demo, :slack_client, FakeSlackClient)
    System.delete_env("SLACK_BOT_TOKEN")

    on_exit(fn ->
      if previous_slack_client do
        Application.put_env(:jido_connect_demo, :slack_client, previous_slack_client)
      else
        Application.delete_env(:jido_connect_demo, :slack_client)
      end

      restore_env("SLACK_BOT_TOKEN", previous_slack_bot_token)
    end)
  end

  test "GET /health", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200) == %{"ok" => true}
  end

  test "GET /integrations lists provider statuses", %{conn: conn} do
    conn = get(conn, ~p"/integrations")

    assert %{"integrations" => integrations} = json_response(conn, 200)
    assert Enum.any?(integrations, &match?(%{"id" => "github", "status" => "available"}, &1))
    assert Enum.any?(integrations, &match?(%{"id" => "slack", "status" => "available"}, &1))
    assert Enum.any?(integrations, &match?(%{"id" => "google", "status" => "planned"}, &1))
  end

  test "GET /integrations/catalog searches discovered providers", %{conn: conn} do
    conn = get(conn, ~p"/integrations/catalog?q=issue")

    assert %{"catalog" => catalog} = json_response(conn, 200)
    assert [%{"id" => "github", "actions" => actions}] = catalog
    assert Enum.any?(actions, &match?(%{"id" => "github.issue.list"}, &1))

    conn = get(conn, ~p"/integrations/catalog?auth_kind=oauth2")
    assert %{"catalog" => catalog} = json_response(conn, 200)
    assert Enum.any?(catalog, &match?(%{"id" => "github"}, &1))
    assert Enum.any?(catalog, &match?(%{"id" => "slack"}, &1))
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

  test "GET /integrations/slack renders Slack console", %{conn: conn} do
    conn = get(conn, ~p"/integrations/slack")

    assert html_response(conn, 200) =~ "Slack Integration"
    assert html_response(conn, 200) =~ "List Channels"
  end

  test "setup complete stores GitHub App installation connection", %{conn: conn} do
    conn =
      get(
        conn,
        ~p"/integrations/github/setup/complete?installation_id=42&account_type=Organization&account_login=acme"
      )

    assert redirected_to(conn) == ~p"/integrations/github"

    assert [
             %{
               id: "github-installation-42",
               profile: :installation,
               owner_type: :tenant,
               owner_id: "local",
               subject: %{account_login: "acme", account_type: "Organization"}
             }
           ] =
             Store.list_connections(:github)
  end

  test "OAuth callback from GitHub App install stores installation connection", %{conn: conn} do
    secret_dir = tmp_dir()
    previous_dir = System.get_env("JIDO_CONNECT_DEMO_SECRET_DIR")
    previous_secret = System.get_env("GITHUB_CLIENT_SECRET")

    System.put_env("JIDO_CONNECT_DEMO_SECRET_DIR", secret_dir)
    System.delete_env("GITHUB_CLIENT_SECRET")
    File.write!(Path.join(secret_dir, "github-oauth-state.txt"), "stale-oauth-state")

    on_exit(fn ->
      restore_env("JIDO_CONNECT_DEMO_SECRET_DIR", previous_dir)
      restore_env("GITHUB_CLIENT_SECRET", previous_secret)
    end)

    conn =
      get(
        conn,
        ~p"/integrations/github/oauth/callback?code=abc123&installation_id=42&setup_action=install"
      )

    assert redirected_to(conn) == ~p"/integrations/github"

    assert [%{id: "github-installation-42", profile: :installation, owner_type: :installation}] =
             Store.list_connections(:github)

    assert File.exists?(Path.join(secret_dir, "github-oauth-callback.json"))
  end

  test "OAuth callback treats blank secret dir env as unset", %{conn: conn} do
    tmp_root = tmp_dir()
    cwd = Path.join(tmp_root, "dev/demo")
    default_secret_dir = Path.join(tmp_root, ".secrets/dev-demo")
    previous_dir = System.get_env("JIDO_CONNECT_DEMO_SECRET_DIR")
    previous_secret = System.get_env("GITHUB_CLIENT_SECRET")

    File.mkdir_p!(cwd)
    System.put_env("JIDO_CONNECT_DEMO_SECRET_DIR", "")
    System.delete_env("GITHUB_CLIENT_SECRET")

    on_exit(fn ->
      restore_env("JIDO_CONNECT_DEMO_SECRET_DIR", previous_dir)
      restore_env("GITHUB_CLIENT_SECRET", previous_secret)
    end)

    File.cd!(cwd, fn ->
      conn = get(conn, ~p"/integrations/github/oauth/callback?code=abc123")

      assert redirected_to(conn) == ~p"/integrations/github"
      assert File.exists?(Path.join(default_secret_dir, "github-oauth-callback.json"))
    end)
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

  test "Slack bot token connection can run generated list channels action", %{conn: conn} do
    conn =
      post(conn, ~p"/integrations/slack/connections/bot", %{
        "token" => "xoxb-test",
        "tenant_id" => "local"
      })

    assert redirected_to(conn) == ~p"/integrations/slack"
    assert [%{id: "slack-bot-T123"}] = Store.list_connections(:slack)

    conn =
      post(conn, ~p"/integrations/slack/actions/list_channels", %{
        "connection_id" => "slack-bot-T123",
        "types" => "public_channel",
        "limit" => "10",
        "exclude_archived" => "true"
      })

    assert redirected_to(conn) == ~p"/integrations/slack"

    assert [
             %{type: :slack_channel_list, status: :ok, value: {:ok, %{channels: [%{id: "C123"}]}}}
             | _
           ] =
             Store.recent_results()
  end

  test "Slack runtime posts through generated action" do
    assert {:ok, connection} =
             SlackRuntime.create_bot_connection(%{"token" => "xoxb-test"},
               slack_client: FakeSlackClient
             )

    assert {:ok, %{channel: "C123", message: %{text: "Hello"}}} =
             SlackRuntime.run_post_message(
               connection.id,
               %{channel: "C123", text: "Hello"},
               slack_client: FakeSlackClient
             )
  end

  test "in-memory connection can mint lease and run generated action" do
    connection = GitHubRuntime.create_manual_connection(%{"token" => "token"})

    assert {:ok, %{issues: [%{number: 1}]}} =
             GitHubRuntime.run_list_issues(
               connection.id,
               %{repo: "org/repo"},
               access_token: "token",
               github_client: FakeGitHubClient
             )
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
