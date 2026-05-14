defmodule Jido.Connect.Google.SearchConsole.Client.Transport do
  @moduledoc "Google Search Console API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @webmasters_base_url "https://www.googleapis.com"
  @search_console_base_url "https://searchconsole.googleapis.com"

  def webmasters_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: webmasters_base_url())
  end

  def search_console_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: search_console_base_url())
  end

  def webmasters_base_url do
    Application.get_env(
      :jido_connect_google_search_console,
      :google_search_console_webmasters_api_base_url,
      @webmasters_base_url
    )
  end

  def search_console_base_url do
    Application.get_env(
      :jido_connect_google_search_console,
      :google_search_console_api_base_url,
      @search_console_base_url
    )
  end

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
