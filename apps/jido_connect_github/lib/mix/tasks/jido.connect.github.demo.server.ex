defmodule Mix.Tasks.Jido.Connect.Github.Demo.Server do
  @moduledoc """
  Runs a tiny local HTTP server for GitHub App manifest and webhook demos.

      mix jido.connect.github.demo.server
      mix jido.connect.github.demo.server --port 4001

  This is intentionally not a production host. It gives ngrok and GitHub a local
  callback target while the real host integration boundary is still being
  designed.
  """

  use Mix.Task

  @shortdoc "Runs a tiny local GitHub integration demo server"
  @default_port 4001

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, strict: [port: :integer])

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    port = Keyword.get(opts, :port, @default_port)
    File.mkdir_p!(".secrets")

    {:ok, socket} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true
      ])

    Mix.shell().info("""
    GitHub demo server listening on http://127.0.0.1:#{port}

    Routes:
    GET  /health
    GET  /integrations/github/setup
    GET  /integrations/github/setup/complete?code=...
    GET  /integrations/github/oauth/callback
    POST /integrations/github/webhook
    """)

    accept_loop(socket)
  end

  defp accept_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    handle_client(client)
    accept_loop(socket)
  end

  defp handle_client(client) do
    with {:ok, request} <- read_request(client),
         response <- route(request) do
      :gen_tcp.send(client, response)
    end
  after
    :gen_tcp.close(client)
  end

  defp read_request(client) do
    with {:ok, head} <- recv_until_headers(client, ""),
         [request_line | header_lines] <- String.split(head, "\r\n", trim: true),
         [method, target, _version] <- String.split(request_line, " ", parts: 3) do
      headers = parse_headers(header_lines)
      content_length = headers |> Map.get("content-length", "0") |> String.to_integer()
      body = recv_body(client, content_length)

      {:ok, %{method: method, target: target, headers: headers, body: body}}
    else
      _other -> {:error, :bad_request}
    end
  end

  defp recv_until_headers(client, acc) do
    if String.contains?(acc, "\r\n\r\n") do
      [head, rest] = String.split(acc, "\r\n\r\n", parts: 2)
      Process.put(:jido_demo_http_remainder, rest)
      {:ok, head}
    else
      case :gen_tcp.recv(client, 0, 5_000) do
        {:ok, chunk} -> recv_until_headers(client, acc <> chunk)
        error -> error
      end
    end
  end

  defp recv_body(_client, 0), do: ""

  defp recv_body(client, content_length) do
    remainder = Process.delete(:jido_demo_http_remainder) || ""

    cond do
      byte_size(remainder) >= content_length ->
        binary_part(remainder, 0, content_length)

      true ->
        bytes_needed = content_length - byte_size(remainder)
        {:ok, rest} = :gen_tcp.recv(client, bytes_needed, 5_000)
        remainder <> rest
    end
  end

  defp parse_headers(header_lines) do
    Map.new(header_lines, fn line ->
      [key, value] = String.split(line, ":", parts: 2)
      {String.downcase(String.trim(key)), String.trim(value)}
    end)
  end

  defp route(%{method: "GET", target: "/health"}) do
    json(200, %{ok: true})
  end

  defp route(%{method: "GET", target: "/integrations/github/setup"}) do
    text(200, "GitHub setup endpoint is reachable.\n")
  end

  defp route(%{method: "GET", target: target}) do
    uri = URI.parse(target)

    case uri.path do
      "/integrations/github/setup/complete" -> setup_complete(uri)
      "/integrations/github/oauth/callback" -> oauth_callback(uri)
      _other -> text(404, "not found\n")
    end
  end

  defp route(%{method: "POST", target: "/integrations/github/webhook"} = request) do
    delivery = Map.get(request.headers, "x-github-delivery", "local")
    event = Map.get(request.headers, "x-github-event", "unknown")

    case verify_signature(request) do
      :ok ->
        path = ".secrets/github-webhook-#{delivery}.json"
        File.write!(path, request.body)
        json(200, %{ok: true, event: event, delivery: delivery, stored: path})

      {:error, reason} ->
        json(401, %{ok: false, error: reason})
    end
  end

  defp route(_request), do: text(404, "not found\n")

  defp setup_complete(uri) do
    params = URI.decode_query(uri.query || "")

    case Map.get(params, "code") do
      nil ->
        text(400, "missing manifest code\n")

      code ->
        File.write!(".secrets/github-app-code.txt", code)

        text(
          200,
          """
          GitHub App manifest code captured.

          Run:
          mix jido.connect.github.app.convert #{code}
          """
        )
    end
  end

  defp oauth_callback(uri) do
    params = URI.decode_query(uri.query || "")
    File.write!(".secrets/github-oauth-callback.json", Jason.encode!(params, pretty: true))
    text(200, "OAuth callback captured in .secrets/github-oauth-callback.json\n")
  end

  defp verify_signature(request) do
    secret = System.get_env("GITHUB_WEBHOOK_SECRET")
    signature = Map.get(request.headers, "x-hub-signature-256")

    cond do
      is_nil(secret) or secret == "" ->
        :ok

      is_nil(signature) ->
        {:error, "missing signature"}

      valid_signature?(secret, request.body, signature) ->
        :ok

      true ->
        {:error, "invalid signature"}
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

  defp json(status, body) do
    payload = Jason.encode!(body)
    response(status, "application/json", payload)
  end

  defp text(status, body), do: response(status, "text/plain; charset=utf-8", body)

  defp response(status, content_type, body) do
    reason = if status in 200..299, do: "OK", else: "Error"

    """
    HTTP/1.1 #{status} #{reason}\r
    content-type: #{content_type}\r
    content-length: #{byte_size(body)}\r
    connection: close\r
    \r
    #{body}
    """
  end
end
