defmodule Jido.Connect.GitHub.AppAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.AppAuth

  setup {Req.Test, :verify_on_exit!}

  setup do
    private_key = :public_key.generate_key({:rsa, 2048, 65_537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, private_key)])

    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)

    {:ok, private_key: private_key, private_key_pem: pem}
  end

  test "creates a signed GitHub App JWT", %{private_key: private_key, private_key_pem: pem} do
    assert {:ok, jwt} = AppAuth.app_jwt(app_id: 123, private_key_pem: pem, now: 1_700_000_000)
    [encoded_header, encoded_payload, encoded_signature] = String.split(jwt, ".")

    assert %{"alg" => "RS256", "typ" => "JWT"} = decode_json(encoded_header)

    assert %{"iss" => "123", "iat" => 1_699_999_940, "exp" => 1_700_000_600} =
             decode_json(encoded_payload)

    assert :public_key.verify(
             encoded_header <> "." <> encoded_payload,
             :sha256,
             Base.url_decode64!(encoded_signature, padding: false),
             private_key
           )

    assert {:ok, private_key_jwt} = AppAuth.app_jwt(app_id: 123, private_key: private_key)
    assert [_header, _payload, _signature] = String.split(private_key_jwt, ".")
  end

  test "can read a private key from a path", %{private_key_pem: pem} do
    path =
      Path.join(System.tmp_dir!(), "jido-connect-test-#{System.unique_integer([:positive])}.pem")

    File.write!(path, pem)
    on_exit(fn -> File.rm(path) end)

    assert {:ok, jwt} = AppAuth.app_jwt(app_id: 123, private_key_path: path)
    assert [_header, _payload, _signature] = String.split(jwt, ".")
  end

  test "requests an installation access token", %{private_key_pem: pem} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/app/installations/42/access_tokens"
      assert ["Bearer " <> _jwt] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        token: "installation-token",
        expires_at: "2026-04-24T22:00:00Z",
        permissions: %{issues: "write"},
        repositories: [%{full_name: "org/repo"}]
      })
    end)

    assert {:ok, token} =
             AppAuth.installation_token(42, app_id: 123, private_key_pem: pem)

    assert token.token == "installation-token"
    assert token.expires_at == ~U[2026-04-24 22:00:00Z]
    assert token.permissions == %{"issues" => "write"}
    assert token.repositories == [%{"full_name" => "org/repo"}]
  end

  test "builds a credential lease for an installation token", %{private_key_pem: pem} do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        token: "installation-token",
        expires_at: "2026-04-24T22:00:00Z",
        permissions: %{issues: "write"},
        repositories: []
      })
    end)

    context = %{tenant_id: "tenant_1", actor: %{id: "user_1"}}

    assert {:ok, %Connect.CredentialLease{} = lease} =
             AppAuth.installation_credential_lease(42, context,
               app_id: 123,
               private_key_pem: pem,
               connection_id: "conn_42"
             )

    assert lease.connection_id == "conn_42"
    assert lease.expires_at == ~U[2026-04-24 22:00:00Z]
    assert lease.fields.access_token == "installation-token"
    assert lease.fields.github_client == Jido.Connect.GitHub.Client
    assert lease.metadata.installation_id == 42
  end

  test "lists installations and fetches repo installation", %{private_key_pem: pem} do
    Req.Test.stub(__MODULE__, fn
      %{method: "GET", request_path: "/app/installations"} = conn ->
        Req.Test.json(conn, [%{id: 42, account: %{login: "org"}}])

      %{method: "GET", request_path: "/repos/org/repo/installation"} = conn ->
        Req.Test.json(conn, %{id: 42, repository_selection: "selected"})
    end)

    assert {:ok, [%{"id" => 42}]} = AppAuth.list_installations(app_id: 123, private_key_pem: pem)

    assert {:ok, %{"id" => 42, "repository_selection" => "selected"}} =
             AppAuth.repo_installation("org", "repo", app_id: 123, private_key_pem: pem)
  end

  test "normalizes config and provider failures", %{private_key_pem: pem} do
    previous_app_id = System.get_env("GITHUB_APP_ID")
    System.delete_env("GITHUB_APP_ID")

    on_exit(fn ->
      if previous_app_id,
        do: System.put_env("GITHUB_APP_ID", previous_app_id),
        else: System.delete_env("GITHUB_APP_ID")
    end)

    assert {:error, %Error.ConfigError{key: "GITHUB_APP_ID"}} =
             AppAuth.app_jwt(private_key_pem: pem)

    assert {:error, %Error.ConfigError{key: "GITHUB_APP_ID"}} =
             AppAuth.app_jwt(app_id: "", private_key_pem: pem)

    assert {:error, %Error.ConfigError{key: "GITHUB_PRIVATE_KEY_PATH"}} =
             AppAuth.app_jwt(app_id: 123, private_key_pem: "not a pem")

    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{message: "Bad credentials"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :http_error,
              status: 401,
              details: %{message: "Bad credentials"}
            }} =
             AppAuth.installation_token(42, app_id: 123, private_key_pem: pem)
  end

  defp decode_json(value) do
    value
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end
end
