defmodule Jido.Connect.Demo.SlackRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Demo.Store

  @scopes ["channels:read", "chat:write"]

  def create_bot_connection(attrs \\ %{}, opts \\ []) do
    client = slack_client(opts)
    token = Map.get(attrs, "token") || local_env("SLACK_BOT_TOKEN")

    with {:token, false} <- {:token, blank?(token)},
         :ok <- ensure_client(client, :auth_test, 1),
         {:ok, auth} <- client.auth_test(token) do
      team_id = auth["team_id"] || Map.get(attrs, "team_id", "local-slack")
      tenant_id = Map.get(attrs, "tenant_id", "local")
      credential_ref = "demo:slack-bot-#{team_id}"

      connection =
        Connect.Connection.new!(%{
          id: "slack-bot-#{team_id}",
          provider: :slack,
          profile: :bot,
          tenant_id: tenant_id,
          owner_type: :tenant,
          owner_id: team_id,
          status: :connected,
          credential_ref: credential_ref,
          scopes: @scopes,
          metadata: %{
            mode: :bot_token,
            team: auth["team"],
            team_id: team_id,
            workspace_url: auth["url"],
            bot_id: auth["bot_id"],
            bot_user: auth["user"],
            bot_user_id: auth["user_id"]
          }
        })

      Store.put_credential(credential_ref, %{access_token: token})
      {:ok, Store.put_connection(connection)}
    else
      {:token, true} -> {:error, :slack_bot_token_required}
      {:error, reason} -> {:error, reason}
    end
  end

  def ensure_env_connection(opts \\ []) do
    case Store.list_connections(:slack) do
      [] -> create_bot_connection(%{}, opts)
      [connection | _rest] -> {:ok, connection}
    end
  end

  def context_and_lease(connection_id, opts \\ []) do
    with {:ok, connection} <- Store.get_connection(connection_id),
         {:ok, lease} <- lease_for(connection, opts) do
      context =
        Connect.Context.new!(%{
          tenant_id: connection.tenant_id,
          actor: %{id: connection.owner_id, type: connection.owner_type},
          connection: connection
        })

      {:ok, context, lease}
    end
  end

  def run_list_channels(connection_id, params, opts \\ []) do
    with :ok <- ensure_client(slack_client(opts), :list_channels, 2),
         {:ok, context, lease} <- context_and_lease(connection_id, opts) do
      Jido.Connect.Slack.Actions.ListChannels.run(params, %{
        integration_context: context,
        credential_lease: lease
      })
    end
  end

  def run_post_message(connection_id, params, opts \\ []) do
    with :ok <- ensure_client(slack_client(opts), :post_message, 2),
         {:ok, context, lease} <- context_and_lease(connection_id, opts) do
      Jido.Connect.Slack.Actions.PostMessage.run(params, %{
        integration_context: context,
        credential_lease: lease
      })
    end
  end

  def env do
    %{
      "SLACK_CLIENT_ID" => present?("SLACK_CLIENT_ID"),
      "SLACK_CLIENT_SECRET" => present?("SLACK_CLIENT_SECRET"),
      "SLACK_SIGNING_SECRET" => present?("SLACK_SIGNING_SECRET"),
      "SLACK_BOT_TOKEN" => present?("SLACK_BOT_TOKEN")
    }
  end

  def env_value(name)
      when name in [
             "SLACK_CLIENT_ID",
             "SLACK_CLIENT_SECRET",
             "SLACK_SIGNING_SECRET",
             "SLACK_BOT_TOKEN"
           ] do
    local_env(name)
  end

  defp lease_for(%Connect.Connection{} = connection, opts) do
    token =
      Keyword.get(opts, :access_token) ||
        Store.get_credential(connection.credential_ref)[:access_token] ||
        local_env("SLACK_BOT_TOKEN")

    if blank?(token) do
      {:error, :slack_bot_token_required}
    else
      Connect.CredentialLease.new(%{
        connection_id: connection.id,
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        fields: %{
          access_token: token,
          slack_client: slack_client(opts)
        },
        metadata: %{mode: :bot_token}
      })
    end
  end

  defp slack_client(opts) do
    Keyword.get(opts, :slack_client) ||
      Application.get_env(:jido_connect_demo, :slack_client, Jido.Connect.Slack.Client)
  end

  defp ensure_client(client, function, arity) do
    if Code.ensure_loaded?(client) and function_exported?(client, function, arity) do
      :ok
    else
      {:error, {:slack_client_unavailable, client}}
    end
  end

  defp present?(name), do: not blank?(local_env(name))

  defp local_env(name) do
    System.get_env(name) || maybe_read_dotenv(name)
  end

  defp maybe_read_dotenv(name) do
    if Application.get_env(:jido_connect_demo, :read_dotenv?, true) do
      read_dotenv(name)
    end
  end

  defp read_dotenv(name) do
    Enum.find_value(dotenv_paths(), fn path ->
      if File.exists?(path), do: read_dotenv_value(path, name)
    end)
  end

  defp dotenv_paths do
    [
      Path.expand(".env", File.cwd!()),
      Path.expand("../../.env", File.cwd!()),
      Path.expand("../../../../.env", __DIR__)
    ]
    |> Enum.uniq()
  end

  defp read_dotenv_value(path, name) do
    path
    |> File.stream!()
    |> Enum.find_value(fn line ->
      line = String.trim(line)

      cond do
        line == "" -> nil
        String.starts_with?(line, "#") -> nil
        not String.starts_with?(line, name <> "=") -> nil
        true -> line |> String.split("=", parts: 2) |> List.last() |> unquote_value()
      end
    end)
  end

  defp unquote_value(value) do
    value
    |> String.trim()
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
    |> String.trim_leading("'")
    |> String.trim_trailing("'")
  end

  defp blank?(value), do: is_nil(value) or value == ""
end
