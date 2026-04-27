defmodule Jido.Connect.Slack.Client do
  @moduledoc """
  Minimal Slack Web API client for provider handlers and host demos.
  """

  alias Jido.Connect.{Data, Http}

  def list_channels(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/conversations.list", params: list_channels_params(params))
    |> handle_channel_list_response()
  end

  def post_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.postMessage", json: Data.compact(attrs))
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
    |> Data.compact()
  end

  defp request(access_token) do
    Http.bearer_request(
      base_url(),
      access_token,
      req_options: Application.get_env(:jido_connect_slack, :slack_req_options, [])
    )
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
       channel: Data.get(body, "channel"),
       ts: Data.get(body, "ts"),
       message: Data.get(body, "message") || %{}
     }}
  end

  defp handle_message_response(response), do: handle_error_response(response)

  defp handle_map_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_map_response(response), do: handle_error_response(response)

  defp handle_error_response({:ok, %{status: status, body: %{"ok" => false} = body}}) do
    Jido.Connect.Error.provider("Slack API request failed",
      provider: :slack,
      status: status,
      reason: Data.get(body, "error"),
      details: %{body: body}
    )
    |> then(&{:error, &1})
  end

  defp handle_error_response({:ok, %{status: status, body: body}}) do
    Http.provider_error({:ok, %{status: status, body: body}},
      provider: :slack,
      message: "Slack HTTP request failed"
    )
  end

  defp handle_error_response({:error, _reason} = response),
    do: Http.provider_error(response, provider: :slack, message: "Slack request failed")

  defp normalize_channel(channel) when is_map(channel) do
    %{
      id: Data.get(channel, "id"),
      name: Data.get(channel, "name"),
      is_archived: Data.get(channel, "is_archived"),
      is_private: Data.get(channel, "is_private"),
      is_member: Data.get(channel, "is_member")
    }
  end
end
