defmodule Jido.Connect.Google.SearchConsole.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.SearchConsole.Client.Transport

  setup do
    webmasters_url =
      Application.get_env(
        :jido_connect_google_search_console,
        :google_search_console_webmasters_api_base_url
      )

    search_console_url =
      Application.get_env(
        :jido_connect_google_search_console,
        :google_search_console_api_base_url
      )

    on_exit(fn ->
      restore(:google_search_console_webmasters_api_base_url, webmasters_url)
      restore(:google_search_console_api_base_url, search_console_url)
    end)
  end

  test "uses configurable Search Console API base URLs" do
    Application.put_env(
      :jido_connect_google_search_console,
      :google_search_console_webmasters_api_base_url,
      "https://webmasters.example.test"
    )

    Application.put_env(
      :jido_connect_google_search_console,
      :google_search_console_api_base_url,
      "https://search-console.example.test"
    )

    assert Transport.webmasters_base_url() == "https://webmasters.example.test"
    assert Transport.search_console_base_url() == "https://search-console.example.test"
  end

  test "builds Webmasters v3 bearer requests" do
    Application.put_env(
      :jido_connect_google_search_console,
      :google_search_console_webmasters_api_base_url,
      "https://webmasters.example.test"
    )

    request = Transport.webmasters_request("token")

    assert request.options.base_url == "https://webmasters.example.test"
    assert request.headers["authorization"] == ["Bearer token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "builds Search Console v1 bearer requests" do
    Application.put_env(
      :jido_connect_google_search_console,
      :google_search_console_api_base_url,
      "https://search-console.example.test"
    )

    request = Transport.search_console_request("token")

    assert request.options.base_url == "https://search-console.example.test"
    assert request.headers["authorization"] == ["Bearer token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "delegates Google error normalization" do
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

  test "delegates malformed success normalization" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["secret"]}}
            }} =
             Transport.invalid_success_response("bad Search Console response", %{
               "secret" => "long-secret-provider-body"
             })
  end

  defp restore(key, nil), do: Application.delete_env(:jido_connect_google_search_console, key)

  defp restore(key, value),
    do: Application.put_env(:jido_connect_google_search_console, key, value)
end
