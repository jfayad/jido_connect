defmodule Jido.Connect.GitHub.AppAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
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

  defp decode_json(value) do
    value
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end
end
