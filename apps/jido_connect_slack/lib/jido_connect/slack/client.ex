defmodule Jido.Connect.Slack.Client do
  @moduledoc """
  Minimal Slack Web API client for provider handlers and host demos.
  """

  def list_channels(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/conversations.list", params: list_channels_params(params))
    |> handle_channel_list_response()
  end

  def post_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.postMessage", json: compact(attrs))
    |> handle_message_response()
  end

  def auth_test(access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/auth.test")
    |> handle_map_response()
  end

  defp list_channels_params(params) do
    params
    |> Map.take([:types, :exclude_archived, :limit, :cursor, :team_id])
    |> compact()
  end

  defp request(access_token) do
    Req.new(
      base_url: base_url(),
      headers: [
        {"authorization", "Bearer #{access_token}"},
        {"user-agent", "jido-connect"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_slack, :slack_req_options, []))
  end

  defp base_url do
    Application.get_env(:jido_connect_slack, :slack_api_base_url, "https://slack.com/api")
  end

  defp handle_channel_list_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok,
     %{
       channels: Enum.map(Map.get(body, "channels", []), &normalize_channel/1),
       next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
     }}
  end

  defp handle_channel_list_response(response), do: handle_error_response(response)

  defp handle_message_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok,
     %{
       channel: get(body, "channel"),
       ts: get(body, "ts"),
       message: get(body, "message") || %{}
     }}
  end

  defp handle_message_response(response), do: handle_error_response(response)

  defp handle_map_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_map_response(response), do: handle_error_response(response)

  defp handle_error_response({:ok, %{status: status, body: %{"ok" => false} = body}}) do
    {:error, {:slack_api_error, get(body, "error"), status, body}}
  end

  defp handle_error_response({:ok, %{status: status, body: body}}) do
    {:error, {:slack_http_error, status, body}}
  end

  defp handle_error_response({:error, reason}), do: {:error, reason}

  defp normalize_channel(channel) when is_map(channel) do
    %{
      id: get(channel, "id"),
      name: get(channel, "name"),
      is_archived: get(channel, "is_archived"),
      is_private: get(channel, "is_private"),
      is_member: get(channel, "is_member")
    }
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  defp get(map, key), do: Map.get(map, key) || Map.get(map, String.to_atom(key))
end
