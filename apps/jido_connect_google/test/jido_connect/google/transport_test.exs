defmodule Jido.Connect.Google.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Transport

  setup do
    Application.put_env(:jido_connect_google, :google_api_base_url, "https://google.test")

    on_exit(fn ->
      Application.delete_env(:jido_connect_google, :google_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "builds bearer requests with Google defaults" do
    request = Transport.request("token")

    assert request.options.base_url == "https://google.test"
    assert request.headers["authorization"] == ["Bearer token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "normalizes malformed success responses as sanitized provider errors" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["secret"]}}
            }} =
             Transport.invalid_success_response("bad response", %{
               "secret" => "long-secret-provider-body"
             })
  end

  test "normalizes error responses" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :http_error,
              status: 403,
              details: %{message: "denied"}
            }} =
             Transport.handle_error_response(
               {:ok, %{status: 403, body: %{"error" => %{"message" => "denied"}}}}
             )
  end
end
