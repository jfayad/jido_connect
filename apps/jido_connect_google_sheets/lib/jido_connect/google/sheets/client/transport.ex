defmodule Jido.Connect.Google.Sheets.Client.Transport do
  @moduledoc "Google Sheets API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @base_url "https://sheets.googleapis.com"

  def request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: base_url())
  end

  def base_url do
    Application.get_env(:jido_connect_google_sheets, :google_sheets_api_base_url, @base_url)
  end

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
