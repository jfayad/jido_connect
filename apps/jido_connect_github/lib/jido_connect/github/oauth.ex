defmodule Jido.Connect.GitHub.OAuth do
  @moduledoc """
  GitHub OAuth App helpers.

  Hosts own callback state, durable connection storage, and credential storage.
  This module only builds OAuth URLs and exchanges/revokes tokens.
  """

  @authorize_url "https://github.com/login/oauth/authorize"
  @token_url "https://github.com/login/oauth/access_token"
  @api_url "https://api.github.com"

  def authorize_url(opts) when is_list(opts) do
    client_id = fetch!(opts, :client_id, "GITHUB_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)
    scope = opts |> Keyword.get(:scope, "read:user") |> normalize_scope()
    allow_signup = Keyword.get(opts, :allow_signup, true)

    query =
      %{
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: scope,
        state: state,
        allow_signup: to_string(allow_signup)
      }
      |> URI.encode_query()

    @authorize_url <> "?" <> query
  end

  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    client_id = fetch!(opts, :client_id, "GITHUB_CLIENT_ID")
    client_secret = fetch!(opts, :client_secret, "GITHUB_CLIENT_SECRET")

    Req.new(
      base_url: Keyword.get(opts, :base_url, @token_url),
      headers: [
        {"accept", "application/json"},
        {"user-agent", "jido-connect"}
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
    client_id = fetch!(opts, :client_id, "GITHUB_CLIENT_ID")
    client_secret = fetch!(opts, :client_secret, "GITHUB_CLIENT_SECRET")

    Req.new(
      base_url: Keyword.get(opts, :api_base_url, @api_url),
      auth: {:basic, "#{client_id}:#{client_secret}"},
      headers: [
        {"accept", "application/vnd.github+json"},
        {"user-agent", "jido-connect"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_github, :github_oauth_req_options, []))
    |> Req.delete(url: "/applications/#{client_id}/token", json: %{access_token: access_token})
    |> case do
      {:ok, %{status: status}} when status in 200..299 or status == 404 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:github_http_error, status, error_message(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    if error = get(body, "error") do
      {:error, {:github_oauth_error, error, get(body, "error_description")}}
    else
      {:ok,
       %{
         access_token: get(body, "access_token"),
         token_type: get(body, "token_type"),
         scope: get(body, "scope") |> parse_scope()
       }}
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    {:error, {:github_http_error, status, error_message(body)}}
  end

  defp handle_token_response({:error, reason}), do: {:error, reason}

  defp normalize_scope(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
  defp normalize_scope(scope) when is_binary(scope), do: scope

  defp parse_scope(nil), do: []
  defp parse_scope(scope) when is_binary(scope), do: String.split(scope, ~r/[\s,]+/, trim: true)

  defp fetch!(opts, key, env_key) do
    Keyword.get(opts, key) || System.get_env(env_key) ||
      raise ArgumentError, "#{key} or #{env_key} is required"
  end

  defp get(map, key), do: Map.get(map, key) || Map.get(map, String.to_atom(key))

  defp error_message(%{"message" => message}), do: message
  defp error_message(%{message: message}), do: message
  defp error_message(body), do: body
end
