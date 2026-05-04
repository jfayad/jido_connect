defmodule Jido.Connect.GitHub.Client.Transport do
  @moduledoc "GitHub-specific REST transport configuration."

  alias Jido.Connect.{Error, Provider.Transport}

  @api_version "2022-11-28"

  @spec request(String.t()) :: Req.Request.t()
  def request(access_token) when is_binary(access_token) do
    Transport.bearer_request(
      base_url(),
      access_token,
      headers: [
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", @api_version}
      ],
      req_options: Application.get_env(:jido_connect_github, :github_req_options, [])
    )
  end

  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_github, :github_api_base_url, "https://api.github.com")
  end

  @spec handle_error_response(term()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response),
    do:
      Transport.provider_error(response, provider: :github, message: "GitHub API request failed")

  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :github,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
