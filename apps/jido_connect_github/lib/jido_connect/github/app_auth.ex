defmodule Jido.Connect.GitHub.AppAuth do
  @moduledoc """
  GitHub App authentication helpers.

  This module keeps GitHub App credential mechanics in the provider package and
  returns short-lived `Jido.Connect.CredentialLease` values for the core runtime.
  """

  alias Jido.Connect
  alias Jido.Connect.GitHub.Client

  @api_version "2022-11-28"
  @jwt_ttl_seconds 600

  def app_jwt(opts \\ []) do
    with {:ok, app_id} <- fetch_app_id(opts),
         {:ok, private_key} <- fetch_private_key(opts) do
      now = Keyword.get(opts, :now, System.system_time(:second))

      payload = %{
        iat: now - 60,
        exp: now + @jwt_ttl_seconds,
        iss: to_string(app_id)
      }

      {:ok, sign_jwt(payload, private_key)}
    end
  end

  def installation_token(installation_id, opts \\ []) when is_integer(installation_id) do
    with {:ok, jwt} <- app_jwt(opts) do
      body =
        opts
        |> Keyword.take([:repositories, :repository_ids, :permissions])
        |> Map.new()

      jwt
      |> request()
      |> Req.post(url: "/app/installations/#{installation_id}/access_tokens", json: body)
      |> handle_token_response()
    end
  end

  def installation_credential_lease(installation_id, context, opts \\ []) do
    with {:ok, token} <- installation_token(installation_id, opts) do
      connection_id = Keyword.get(opts, :connection_id, "github-installation-#{installation_id}")

      Connect.CredentialLease.new(%{
        connection_id: connection_id,
        expires_at: token.expires_at,
        fields: %{
          access_token: token.token,
          github_client: Keyword.get(opts, :github_client, Client)
        },
        metadata: %{
          installation_id: installation_id,
          context: context,
          permissions: token.permissions,
          repositories: token.repositories
        }
      })
    end
  end

  def list_installations(opts \\ []) do
    with {:ok, jwt} <- app_jwt(opts) do
      jwt
      |> request()
      |> Req.get(url: "/app/installations")
      |> handle_list_response()
    end
  end

  def repo_installation(owner, repo, opts \\ []) do
    with {:ok, jwt} <- app_jwt(opts) do
      jwt
      |> request()
      |> Req.get(url: "/repos/#{owner}/#{repo}/installation")
      |> handle_installation_response()
    end
  end

  defp fetch_app_id(opts) do
    case Keyword.get(opts, :app_id) || System.get_env("GITHUB_APP_ID") do
      nil -> {:error, :github_app_id_required}
      "" -> {:error, :github_app_id_required}
      app_id -> {:ok, app_id}
    end
  end

  defp fetch_private_key(opts) do
    cond do
      private_key = Keyword.get(opts, :private_key) ->
        {:ok, private_key}

      pem = Keyword.get(opts, :private_key_pem) ->
        decode_private_key(pem)

      path = Keyword.get(opts, :private_key_path) || System.get_env("GITHUB_PRIVATE_KEY_PATH") ->
        path
        |> File.read()
        |> then(fn
          {:ok, pem} -> decode_private_key(pem)
          {:error, reason} -> {:error, {:github_private_key_read_failed, reason}}
        end)

      true ->
        {:error, :github_private_key_required}
    end
  end

  defp decode_private_key(pem) when is_binary(pem) do
    [entry] = :public_key.pem_decode(pem)
    {:ok, :public_key.pem_entry_decode(entry)}
  rescue
    _error -> {:error, :github_private_key_invalid}
  end

  defp sign_jwt(payload, private_key) do
    header = %{alg: "RS256", typ: "JWT"}

    signing_input =
      [header, payload]
      |> Enum.map(&(&1 |> Jason.encode!() |> base64url()))
      |> Enum.join(".")

    signature =
      signing_input
      |> :public_key.sign(:sha256, private_key)
      |> base64url()

    signing_input <> "." <> signature
  end

  defp request(jwt) do
    Req.new(
      base_url: base_url(),
      headers: [
        {"accept", "application/vnd.github+json"},
        {"authorization", "Bearer #{jwt}"},
        {"x-github-api-version", @api_version},
        {"user-agent", "jido-connect"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_github, :github_req_options, []))
  end

  defp base_url do
    Application.get_env(:jido_connect_github, :github_api_base_url, "https://api.github.com")
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok,
     %{
       token: fetch!(body, "token"),
       expires_at: parse_datetime!(fetch!(body, "expires_at")),
       permissions: get(body, "permissions") || %{},
       repositories: get(body, "repositories") || []
     }}
  end

  defp handle_token_response(response), do: handle_error_response(response)

  defp handle_list_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_list_response(response), do: handle_error_response(response)

  defp handle_installation_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_installation_response(response), do: handle_error_response(response)

  defp handle_error_response({:ok, %{status: status, body: body}}) do
    {:error, {:github_http_error, status, error_message(body)}}
  end

  defp handle_error_response({:error, reason}), do: {:error, reason}

  defp parse_datetime!(value) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(value)
    datetime
  end

  defp fetch!(map, key), do: get(map, key) || raise(KeyError, key: key, term: map)
  defp get(map, key), do: Map.get(map, key) || Map.get(map, String.to_atom(key))

  defp error_message(%{"message" => message}), do: message
  defp error_message(%{message: message}), do: message
  defp error_message(body), do: body

  defp base64url(value) do
    Base.url_encode64(value, padding: false)
  end
end
