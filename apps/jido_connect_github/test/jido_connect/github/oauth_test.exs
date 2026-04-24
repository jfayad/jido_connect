defmodule Jido.Connect.GitHub.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.GitHub.OAuth

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_oauth_req_options)
    end)
  end

  test "builds authorize URL" do
    url =
      OAuth.authorize_url(
        client_id: "client",
        redirect_uri: "https://demo.test/integrations/github/oauth/callback",
        scope: ["repo", "read:user"],
        state: "state"
      )

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "github.com"
    assert uri.path == "/login/oauth/authorize"
    assert params["client_id"] == "client"
    assert params["redirect_uri"] == "https://demo.test/integrations/github/oauth/callback"
    assert params["scope"] == "repo read:user"
    assert params["state"] == "state"
  end

  test "exchanges code for token" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"

      Req.Test.json(conn, %{
        access_token: "token",
        token_type: "bearer",
        scope: "repo,read:user"
      })
    end)

    assert {:ok, token} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               base_url: "https://github.test"
             )

    assert token.access_token == "token"
    assert token.scope == ["repo", "read:user"]
  end

  test "returns OAuth error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        error: "bad_verification_code",
        error_description: "The code passed is incorrect or expired."
      })
    end)

    assert {:error,
            {:github_oauth_error, "bad_verification_code",
             "The code passed is incorrect or expired."}} =
             OAuth.exchange_code("bad",
               client_id: "client",
               client_secret: "secret",
               base_url: "https://github.test"
             )
  end
end
