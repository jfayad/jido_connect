defmodule Jido.Connect.Slack.Client do
  @moduledoc """
  Minimal Slack Web API client for provider handlers and host demos.
  """

  alias Jido.Connect.{Data, Error, Http}

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

  def update_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.update", json: Data.compact(attrs))
    |> handle_message_response()
  end

  def delete_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.delete", json: Data.compact(attrs))
    |> handle_delete_message_response()
  end

  def list_users(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/users.list", params: list_users_params(params))
    |> handle_user_list_response()
  end

  def user_info(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/users.info", params: user_info_params(params))
    |> handle_user_info_response()
  end

  def lookup_user_by_email(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/users.lookupByEmail", params: lookup_user_by_email_params(params))
    |> handle_lookup_user_by_email_response()
  end

  def auth_test(access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/auth.test")
    |> handle_map_response()
  end

  def team_info(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/team.info", params: team_info_params(params))
    |> handle_team_info_response()
  end

  defp list_channels_params(params) do
    params
    |> Map.take([:types, :exclude_archived, :limit, :cursor, :team_id])
    |> Data.compact()
  end

  defp list_users_params(params) do
    params
    |> Map.take([:limit, :cursor, :team_id, :include_locale])
    |> Data.compact()
  end

  defp user_info_params(params) do
    params
    |> Map.take([:user, :include_locale])
    |> Data.compact()
  end

  defp lookup_user_by_email_params(params) do
    params
    |> Map.take([:email])
    |> Data.compact()
  end

  defp team_info_params(params) do
    case Data.get(params, :team_id) do
      nil -> %{}
      team_id -> %{team: team_id}
    end
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
    with channels when is_list(channels) <- Map.get(body, "channels", []),
         true <- Enum.all?(channels, &is_map/1) do
      {:ok,
       %{
         channels: Enum.map(channels, &normalize_channel/1),
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other -> invalid_success_response("Slack channel list response was invalid", body)
    end
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

  defp handle_delete_message_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(body, "channel"),
       ts: Data.get(body, "ts")
     }}
  end

  defp handle_delete_message_response(response), do: handle_error_response(response)

  defp handle_user_list_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    with users when is_list(users) <- Map.get(body, "members", []),
         true <- Enum.all?(users, &is_map/1) do
      {:ok,
       %{
         users: Enum.map(users, &normalize_user/1),
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other -> invalid_success_response("Slack user list response was invalid", body)
    end
  end

  defp handle_user_list_response(response), do: handle_error_response(response)

  defp handle_user_info_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    case Data.get(body, "user") do
      user when is_map(user) -> {:ok, %{user: normalize_user_info(user)}}
      _other -> invalid_success_response("Slack user info response was invalid", body)
    end
  end

  defp handle_user_info_response(response), do: handle_error_response(response)

  defp handle_lookup_user_by_email_response(
         {:ok, %{body: %{"ok" => false, "error" => "users_not_found"} = body}}
       ) do
    {:error,
     Error.provider("Slack user was not found",
       provider: :slack,
       status: 404,
       reason: :not_found,
       details: %{body: body}
     )}
  end

  defp handle_lookup_user_by_email_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}}
       )
       when status in 200..299 do
    case Data.get(body, "user") do
      user when is_map(user) -> {:ok, %{user: normalize_user_info(user)}}
      _other -> invalid_success_response("Slack user lookup by email response was invalid", body)
    end
  end

  defp handle_lookup_user_by_email_response(response), do: handle_error_response(response)

  defp handle_map_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_map_response(response), do: handle_error_response(response)

  defp handle_team_info_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    case Data.get(body, "team") do
      team when is_map(team) -> {:ok, %{team: team}}
      _other -> invalid_success_response("Slack team info response was invalid", body)
    end
  end

  defp handle_team_info_response(response), do: handle_error_response(response)

  defp handle_error_response({:ok, %{status: status, body: %{"ok" => false} = body}}) do
    Error.provider("Slack API request failed",
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

  defp normalize_user(user) when is_map(user) do
    %{
      id: Data.get(user, "id"),
      team_id: Data.get(user, "team_id"),
      name: Data.get(user, "name"),
      real_name: Data.get(user, "real_name"),
      tz: Data.get(user, "tz"),
      deleted: Data.get(user, "deleted"),
      is_bot: Data.get(user, "is_bot"),
      is_app_user: Data.get(user, "is_app_user"),
      updated: Data.get(user, "updated"),
      profile: Data.get(user, "profile")
    }
    |> Data.compact()
  end

  defp normalize_user_info(user) when is_map(user) do
    user
    |> normalize_user()
    |> Map.put(:profile, normalize_profile(Data.get(user, "profile")))
    |> Data.compact()
  end

  defp normalize_profile(profile) when is_map(profile) do
    normalized =
      %{
        avatar_hash: Data.get(profile, "avatar_hash"),
        bot_id: Data.get(profile, "bot_id"),
        display_name: Data.get(profile, "display_name"),
        display_name_normalized: Data.get(profile, "display_name_normalized"),
        email: Data.get(profile, "email"),
        first_name: Data.get(profile, "first_name"),
        image_24: Data.get(profile, "image_24"),
        image_32: Data.get(profile, "image_32"),
        image_48: Data.get(profile, "image_48"),
        image_72: Data.get(profile, "image_72"),
        image_192: Data.get(profile, "image_192"),
        image_512: Data.get(profile, "image_512"),
        last_name: Data.get(profile, "last_name"),
        phone: Data.get(profile, "phone"),
        real_name: Data.get(profile, "real_name"),
        real_name_normalized: Data.get(profile, "real_name_normalized"),
        skype: Data.get(profile, "skype"),
        status_emoji: Data.get(profile, "status_emoji"),
        status_text: Data.get(profile, "status_text"),
        team: Data.get(profile, "team"),
        title: Data.get(profile, "title")
      }
      |> Data.compact()

    if map_size(normalized) == 0, do: nil, else: normalized
  end

  defp normalize_profile(_profile), do: nil

  defp invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :slack,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
