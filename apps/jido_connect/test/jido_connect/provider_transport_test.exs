defmodule Jido.Connect.Provider.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Provider.Transport

  setup {Req.Test, :verify_on_exit!}

  test "builds bearer requests and executes through injected Req options" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/resource"
      assert %{"page" => "1"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")
      assert ["jido-connect"] = Plug.Conn.get_req_header(conn, "user-agent")
      assert ["demo"] = Plug.Conn.get_req_header(conn, "x-provider")

      Req.Test.json(conn, %{ok: true})
    end)

    request =
      Transport.bearer_request("https://provider.test", "token",
        headers: [{"x-provider", "demo"}],
        req_options: [plug: {Req.Test, __MODULE__}]
      )

    assert {:ok, %{status: 200, body: %{"ok" => true}}} =
             Transport.request(request, :get, url: "/resource", params: [page: 1])
  end

  test "normalizes provider errors through the shared public error shape" do
    assert {:error,
            %Error.ProviderError{
              provider: :demo,
              reason: :http_error,
              status: 500,
              details: %{body_summary: %{type: :map, keys: ["token"]}}
            }} =
             Transport.provider_error({:ok, %{status: 500, body: %{"token" => "secret"}}},
               provider: :demo,
               message: "Demo request failed"
             )
  end
end
