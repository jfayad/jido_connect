defmodule Jido.Connect.GitHub.OAuth do
  @moduledoc """
  GitHub OAuth App helpers.

  Hosts own callback state, durable connection storage, and credential storage.
  This module only builds OAuth URLs and exchanges/revokes tokens.
  """

  @authorize_url "https://github.com/login/oauth/authorize"
  @token_url "https://github.com/login/oauth/access_token"
  @api_url "https://api.github.com"

  alias Jido.Connect.{Data, Error, Scope}
  alias Jido.Connect.OAuth, as: CoreOAuth

  def authorize_url(opts) when is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)
    scope = opts |> Keyword.get(:scope, "read:user") |> Scope.encode(separator: " ")
    allow_signup = Keyword.get(opts, :allow_signup, true)

    CoreOAuth.authorize_url(@authorize_url, %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      state: state,
      allow_signup: to_string(allow_signup)
    })
  end

  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITHUB_CLIENT_SECRET")

    CoreOAuth.req(
      base_url: Keyword.get(opts, :base_url, @token_url),
      headers: [
        {"accept", "application/json"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_github, :github_oauth_req_options, []))
    |> Req.post(
      json: %{
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: Keyword.get(opts, :redirect_uri),
        state: Keyword.get(opts, :state)
      }
    )
    |> handle_token_response()
  end

  def revoke_token(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITHUB_CLIENT_SECRET")

    CoreOAuth.req(
      base_url: Keyword.get(opts, :api_base_url, @api_url),
      auth: {:basic, "#{client_id}:#{client_secret}"},
      headers: [
        {"accept", "application/vnd.github+json"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_github, :github_oauth_req_options, []))
    |> Req.delete(url: "/applications/#{client_id}/token", json: %{access_token: access_token})
    |> case do
      {:ok, %{status: status}} when status in 200..299 or status == 404 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error,
         Error.provider("GitHub OAuth token revocation failed",
           provider: :github,
           reason: :http_error,
           status: status,
           details: %{message: error_message(body), body: body}
         )}

      {:error, reason} ->
        {:error,
         Error.provider("GitHub OAuth token revocation failed",
           provider: :github,
           reason: :request_error,
           details: %{reason: reason}
         )}
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    if error = Data.get(body, "error") do
      {:error,
       Error.provider("GitHub OAuth code exchange failed",
         provider: :github,
         reason: error,
         status: status,
         details: %{description: Data.get(body, "error_description"), body: body}
       )}
    else
      {:ok,
       %{
         access_token: Data.get(body, "access_token"),
         token_type: Data.get(body, "token_type"),
         scope: body |> Data.get("scope") |> Scope.parse()
       }}
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    {:error,
     Error.provider("GitHub OAuth code exchange failed",
       provider: :github,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  defp handle_token_response({:error, reason}) do
    {:error,
     Error.provider("GitHub OAuth code exchange failed",
       provider: :github,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp error_message(body) when is_map(body), do: Data.get(body, "message", body)
  defp error_message(body), do: body
end
