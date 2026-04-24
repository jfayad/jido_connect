defmodule Jido.Connect.DemoWeb.IntegrationController do
  use Jido.Connect.DemoWeb, :controller

  @github_authorize_url "https://github.com/login/oauth/authorize"

  def index(conn, _params) do
    json(conn, %{integrations: Jido.Connect.Demo.Integrations.api_index()})
  end

  def health(conn, _params), do: json(conn, %{ok: true})

  def github_setup(conn, _params) do
    text(conn, "GitHub setup endpoint is reachable.\n")
  end

  def github_setup_complete(conn, %{"code" => code}) do
    path = write_secret!("github-app-code.txt", code)

    text(conn, """
    GitHub App manifest code captured.

    Stored: #{path}

    Run from the repo root:
    mix jido.connect.github.app.convert #{code}
    """)
  end

  def github_setup_complete(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> text("missing manifest code\n")
  end

  def github_oauth_start(conn, params) do
    client_id = Map.get(params, "client_id") || System.get_env("GITHUB_CLIENT_ID")

    if blank?(client_id) do
      conn
      |> put_status(:bad_request)
      |> json(%{ok: false, error: "missing GITHUB_CLIENT_ID"})
    else
      state = random_token()
      write_secret!("github-oauth-state.txt", state)

      query =
        URI.encode_query(%{
          client_id: client_id,
          redirect_uri: github_callback_url(conn),
          scope: Map.get(params, "scope", "repo"),
          state: state
        })

      redirect(conn, external: @github_authorize_url <> "?" <> query)
    end
  end

  def github_oauth_callback(conn, params) do
    stored_state = read_secret("github-oauth-state.txt")

    result =
      cond do
        blank?(Map.get(params, "code")) ->
          %{ok: false, error: "missing code", params: params}

        not blank?(stored_state) and Map.get(params, "state") != stored_state ->
          %{ok: false, error: "invalid state", params: params}

        true ->
          %{ok: true, params: params}
      end

    path = write_secret!("github-oauth-callback.json", Jason.encode!(result, pretty: true))

    if result.ok do
      text(conn, "OAuth callback captured in #{path}\n")
    else
      conn
      |> put_status(:bad_request)
      |> json(result)
    end
  end

  def github_webhook(conn, _params) do
    delivery = get_req_header(conn, "x-github-delivery") |> List.first() || "local"
    event = get_req_header(conn, "x-github-event") |> List.first() || "unknown"

    body = conn.assigns[:raw_body] || ""

    with :ok <- verify_signature(conn, body) do
      path = write_secret!("github-webhook-#{delivery}.json", body)

      json(conn, %{
        ok: true,
        event: event,
        delivery: delivery,
        stored: path
      })
    else
      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: reason})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: inspect(reason)})
    end
  end

  defp github_callback_url(_conn) do
    Jido.Connect.DemoWeb.Endpoint.url() <> ~p"/integrations/github/oauth/callback"
  end

  defp verify_signature(conn, body) do
    secret = System.get_env("GITHUB_WEBHOOK_SECRET")

    if blank?(secret) do
      :ok
    else
      signature = get_req_header(conn, "x-hub-signature-256") |> List.first()

      cond do
        is_nil(signature) ->
          {:error, "missing signature"}

        valid_signature?(secret, body, signature) ->
          :ok

        true ->
          {:error, "invalid signature"}
      end
    end
  end

  defp valid_signature?(secret, body, "sha256=" <> expected) do
    actual =
      :hmac
      |> :crypto.mac(:sha256, secret, body)
      |> Base.encode16(case: :lower)

    secure_compare(actual, expected)
  end

  defp valid_signature?(_secret, _body, _signature), do: false

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {left_byte, right_byte}, acc ->
      :erlang.bor(acc, :erlang.bxor(left_byte, right_byte))
    end)
    |> Kernel.==(0)
  end

  defp secure_compare(_left, _right), do: false

  defp random_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp write_secret!(name, contents) do
    dir = secret_dir()
    File.mkdir_p!(dir)
    path = Path.join(dir, name)
    File.write!(path, contents)
    path
  end

  defp read_secret(name) do
    secret_dir()
    |> Path.join(name)
    |> File.read()
    |> case do
      {:ok, contents} -> contents
      {:error, _reason} -> nil
    end
  end

  defp secret_dir do
    System.get_env("JIDO_CONNECT_DEMO_SECRET_DIR") ||
      Path.expand("../../.secrets/dev-demo", File.cwd!())
  end

  defp blank?(value), do: is_nil(value) or value == ""
end
