defmodule Jido.Connect.GitHub.Client.ResponseTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
  end

  test "normalizes error responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{message: "Resource not accessible"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :http_error,
              status: 403,
              details: %{message: "Resource not accessible"}
            }} =
             Client.fetch_authenticated_user("token")
  end

  test "normalizes malformed successful responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{unexpected: true})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["unexpected"]}}
            }} = Client.list_issues("org/repo", "open", "token")
  end
end
