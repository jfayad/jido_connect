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

  def get_thread_replies(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/conversations.replies", params: thread_replies_params(params))
    |> handle_thread_replies_response(params)
  end

  def search_messages(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/search.messages", params: search_messages_params(params))
    |> handle_search_messages_response()
  end

  def get_conversation_info(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/conversations.info", params: conversation_info_params(params))
    |> handle_conversation_info_response(params)
  end

  def create_channel(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/conversations.create", json: create_channel_params(params))
    |> handle_create_channel_response()
  end

  def archive_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/conversations.archive", json: archive_conversation_params(params))
    |> handle_archive_conversation_response(params)
  end

  def unarchive_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/conversations.unarchive", json: unarchive_conversation_params(params))
    |> handle_unarchive_conversation_response(params)
  end

  def rename_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/conversations.rename", json: rename_conversation_params(params))
    |> handle_rename_conversation_response()
  end

  def invite_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/conversations.invite", json: invite_conversation_params(params))
    |> handle_invite_conversation_response(params)
  end

  def kick_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/conversations.kick", json: kick_conversation_params(params))
    |> handle_kick_conversation_response(params)
  end

  def open_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/conversations.open", json: open_conversation_params(params))
    |> handle_open_conversation_response()
  end

  def list_conversation_members(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/conversations.members", params: conversation_members_params(params))
    |> handle_conversation_members_response(params)
  end

  def post_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.postMessage", json: Data.compact(attrs))
    |> handle_message_response()
  end

  def post_ephemeral(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.postEphemeral", json: ephemeral_message_params(attrs))
    |> handle_ephemeral_message_response(attrs)
  end

  def schedule_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.scheduleMessage", json: scheduled_message_params(attrs))
    |> handle_scheduled_message_response()
  end

  def delete_scheduled_message(attrs, access_token)
      when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/chat.deleteScheduledMessage", json: delete_scheduled_message_params(attrs))
    |> handle_delete_scheduled_message_response(attrs)
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

  def add_reaction(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/reactions.add", json: reaction_params(attrs))
    |> handle_add_reaction_response(attrs)
  end

  def remove_reaction(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/reactions.remove", json: reaction_params(attrs))
    |> handle_remove_reaction_response(attrs)
  end

  def get_reactions(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.get(url: "/reactions.get", params: get_reactions_params(params))
    |> handle_get_reactions_response(params)
  end

  def upload_file(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    content = Data.get(attrs, :content, "")

    with {:ok, upload} <-
           access_token
           |> request()
           |> Req.post(
             url: "/files.getUploadURLExternal",
             json: upload_url_params(attrs, content)
           )
           |> handle_upload_url_response(),
         {:ok, _response} <- post_file_content(Data.get(upload, :upload_url), content),
         {:ok, complete} <-
           access_token
           |> request()
           |> Req.post(
             url: "/files.completeUploadExternal",
             json: complete_upload_params(attrs, upload)
           )
           |> handle_complete_upload_response(upload) do
      {:ok, complete}
    end
  end

  def share_file(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(
      url: "/files.completeUploadExternal",
      json: share_file_params(attrs)
    )
    |> handle_share_file_response(attrs)
  end

  def delete_file(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> request()
    |> Req.post(url: "/files.delete", json: delete_file_params(attrs))
    |> handle_delete_file_response(attrs)
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

  defp thread_replies_params(params) do
    params
    |> Map.take([:channel, :ts, :limit, :cursor, :oldest, :latest, :inclusive])
    |> Data.compact()
  end

  defp search_messages_params(params) do
    params
    |> Map.take([:query, :sort, :sort_dir, :count, :page, :cursor, :highlight, :team_id])
    |> Data.compact()
  end

  defp conversation_info_params(params) do
    params
    |> Map.take([:channel, :include_locale])
    |> Data.compact()
  end

  defp create_channel_params(params) do
    params
    |> Map.take([:name, :is_private, :team_id])
    |> Data.compact()
  end

  defp archive_conversation_params(params) do
    params
    |> Map.take([:channel])
    |> Data.compact()
  end

  defp unarchive_conversation_params(params) do
    params
    |> Map.take([:channel])
    |> Data.compact()
  end

  defp rename_conversation_params(params) do
    params
    |> Map.take([:channel, :name])
    |> Data.compact()
  end

  defp invite_conversation_params(params) do
    params
    |> Map.take([:channel, :users, :force])
    |> maybe_join_users()
    |> Data.compact()
  end

  defp kick_conversation_params(params) do
    params
    |> Map.take([:channel, :user])
    |> Data.compact()
  end

  defp open_conversation_params(params) do
    params
    |> Map.take([:users, :channel, :return_im, :prevent_creation])
    |> maybe_join_users()
    |> Data.compact()
  end

  defp conversation_members_params(params) do
    params
    |> Map.take([:channel, :limit, :cursor])
    |> Data.compact()
  end

  defp ephemeral_message_params(params) do
    params
    |> Map.take([:channel, :user, :text, :thread_ts, :blocks])
    |> Data.compact()
  end

  defp scheduled_message_params(params) do
    params
    |> Map.take([:channel, :text, :post_at, :thread_ts, :reply_broadcast, :blocks])
    |> Data.compact()
  end

  defp delete_scheduled_message_params(params) do
    params
    |> Map.take([:channel, :scheduled_message_id])
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

  defp reaction_params(params) do
    params
    |> Map.take([:channel, :timestamp, :name])
    |> Data.compact()
  end

  defp get_reactions_params(params) do
    params
    |> Map.take([:channel, :timestamp, :file, :file_comment, :full])
    |> Data.compact()
  end

  defp upload_url_params(params, content) do
    params
    |> Map.take([:filename, :alt_txt, :snippet_type])
    |> Map.put(:length, byte_size(content))
    |> Data.compact()
  end

  defp complete_upload_params(params, upload) do
    file =
      %{id: Data.get(upload, :file_id), title: Data.get(params, :title)}
      |> Data.compact()

    params
    |> Map.take([:channel_id, :initial_comment, :thread_ts])
    |> Map.put(:files, [file])
    |> Data.compact()
  end

  defp share_file_params(params) do
    file =
      %{id: Data.get(params, :file_id), title: Data.get(params, :title)}
      |> Data.compact()

    params
    |> Map.take([:channels, :initial_comment, :thread_ts])
    |> Map.put(:files, [file])
    |> Data.compact()
  end

  defp maybe_join_users(%{users: users} = params) when is_list(users) do
    Map.put(params, :users, Enum.join(users, ","))
  end

  defp maybe_join_users(params), do: params

  defp delete_file_params(params) do
    params
    |> Map.take([:file_id])
    |> Map.new(fn {:file_id, file_id} -> {:file, file_id} end)
    |> Data.compact()
  end

  defp post_file_content(upload_url, content) when is_binary(upload_url) and is_binary(content) do
    Req.new(url: upload_url, headers: [{"content-type", "application/octet-stream"}])
    |> Req.merge(Application.get_env(:jido_connect_slack, :slack_upload_req_options, []))
    |> Req.post(body: content)
    |> handle_file_content_response()
  end

  defp post_file_content(_upload_url, _content) do
    {:error,
     Error.provider("Slack upload URL response was invalid",
       provider: :slack,
       reason: :invalid_response
     )}
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

  defp handle_thread_replies_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}},
         params
       )
       when status in 200..299 do
    with messages when is_list(messages) <- Map.get(body, "messages", []),
         true <- Enum.all?(messages, &is_map/1) do
      {:ok,
       %{
         channel: Data.get(params, :channel),
         thread_ts: Data.get(params, :ts),
         messages: messages,
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || "",
         has_more: Data.get(body, "has_more", false)
       }}
    else
      _other -> invalid_success_response("Slack thread replies response was invalid", body)
    end
  end

  defp handle_thread_replies_response(response, _params), do: handle_error_response(response)

  defp handle_search_messages_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    with messages when is_map(messages) <- Map.get(body, "messages", %{}),
         matches when is_list(matches) <- Map.get(messages, "matches", []),
         true <- Enum.all?(matches, &is_map/1) do
      {:ok,
       %{
         query: Data.get(body, "query"),
         messages: matches,
         total_count: search_total_count(messages),
         pagination: Data.get(messages, "pagination", %{}),
         paging: Data.get(messages, "paging", %{}),
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other -> invalid_success_response("Slack message search response was invalid", body)
    end
  end

  defp handle_search_messages_response(response), do: handle_error_response(response)

  defp handle_conversation_info_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}},
         params
       )
       when status in 200..299 do
    case Map.get(body, "channel") do
      conversation when is_map(conversation) ->
        {:ok,
         %{
           channel: Data.get(conversation, "id", Data.get(params, :channel)),
           conversation: conversation
         }}

      _other ->
        invalid_success_response("Slack conversation info response was invalid", body)
    end
  end

  defp handle_conversation_info_response(response, _params), do: handle_error_response(response)

  defp handle_create_channel_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    case Data.get(body, "channel") do
      channel when is_map(channel) -> {:ok, %{channel: normalize_channel(channel)}}
      _other -> invalid_success_response("Slack channel create response was invalid", body)
    end
  end

  defp handle_create_channel_response(response), do: handle_error_response(response)

  defp handle_archive_conversation_response(
         {:ok, %{status: status, body: %{"ok" => true}}},
         params
       )
       when status in 200..299 do
    {:ok, %{channel: Data.get(params, :channel)}}
  end

  defp handle_archive_conversation_response(response, _params),
    do: handle_error_response(response)

  defp handle_unarchive_conversation_response(
         {:ok, %{status: status, body: %{"ok" => true}}},
         params
       )
       when status in 200..299 do
    {:ok, %{channel: Data.get(params, :channel)}}
  end

  defp handle_unarchive_conversation_response(response, _params),
    do: handle_error_response(response)

  defp handle_rename_conversation_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    case Data.get(body, "channel") do
      channel when is_map(channel) -> {:ok, %{channel: normalize_channel(channel)}}
      _other -> invalid_success_response("Slack channel rename response was invalid", body)
    end
  end

  defp handle_rename_conversation_response(response), do: handle_error_response(response)

  defp handle_invite_conversation_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}},
         params
       )
       when status in 200..299 do
    case Data.get(body, "channel") do
      channel when is_map(channel) ->
        {:ok,
         %{
           channel: normalize_channel(channel),
           invited_users: invited_users(params, []),
           failed_users: [],
           partial_failure: false
         }}

      _other ->
        invalid_success_response("Slack conversation invite response was invalid", body)
    end
  end

  defp handle_invite_conversation_response(
         {:ok, %{status: status, body: %{"ok" => false, "errors" => errors} = body}},
         params
       )
       when status in 200..299 and is_list(errors) do
    failed_users = normalize_invite_errors(errors)

    if Data.get(params, :force, false) do
      {:ok,
       %{
         channel: %{id: Data.get(params, :channel)},
         invited_users: invited_users(params, failed_users),
         failed_users: failed_users,
         partial_failure: true
       }}
    else
      {:error,
       Error.provider("Slack conversation invite partially failed",
         provider: :slack,
         status: status,
         reason: Data.get(body, "error"),
         details: %{body: body, failed_users: failed_users}
       )}
    end
  end

  defp handle_invite_conversation_response(response, _params), do: handle_error_response(response)

  defp handle_kick_conversation_response(
         {:ok, %{status: status, body: %{"ok" => true}}},
         params
       )
       when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(params, :channel),
       user: Data.get(params, :user)
     }}
  end

  defp handle_kick_conversation_response(response, _params), do: handle_error_response(response)

  defp handle_open_conversation_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    case Data.get(body, "channel") do
      conversation when is_map(conversation) ->
        conversation = normalize_conversation(conversation)

        {:ok,
         %{
           channel: Data.get(conversation, :id),
           conversation: conversation
         }}

      _other ->
        invalid_success_response("Slack conversation open response was invalid", body)
    end
  end

  defp handle_open_conversation_response(response), do: handle_error_response(response)

  defp handle_conversation_members_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}},
         params
       )
       when status in 200..299 do
    with members when is_list(members) <- Map.get(body, "members", []),
         true <- Enum.all?(members, &is_binary/1) do
      {:ok,
       %{
         channel: Data.get(params, :channel),
         members: members,
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other -> invalid_success_response("Slack conversation members response was invalid", body)
    end
  end

  defp handle_conversation_members_response(response, _params),
    do: handle_error_response(response)

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

  defp handle_ephemeral_message_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}},
         attrs
       )
       when status in 200..299 do
    case Data.get(body, "message_ts") do
      message_ts when is_binary(message_ts) ->
        {:ok,
         %{
           channel: Data.get(attrs, :channel),
           user: Data.get(attrs, :user),
           message_ts: message_ts
         }}

      _other ->
        invalid_success_response("Slack ephemeral message response was invalid", body)
    end
  end

  defp handle_ephemeral_message_response(response, _attrs), do: handle_error_response(response)

  defp handle_scheduled_message_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    with channel when is_binary(channel) <- Data.get(body, "channel"),
         scheduled_message_id when is_binary(scheduled_message_id) <-
           Data.get(body, "scheduled_message_id"),
         post_at when is_integer(post_at) <- normalize_post_at(Data.get(body, "post_at")) do
      {:ok,
       %{
         channel: channel,
         scheduled_message_id: scheduled_message_id,
         post_at: post_at,
         message: Data.get(body, "message") || %{}
       }}
    else
      _other -> invalid_success_response("Slack scheduled message response was invalid", body)
    end
  end

  defp handle_scheduled_message_response(response), do: handle_error_response(response)

  defp handle_delete_scheduled_message_response(
         {:ok, %{status: status, body: %{"ok" => true}}},
         attrs
       )
       when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(attrs, :channel),
       scheduled_message_id: Data.get(attrs, :scheduled_message_id)
     }}
  end

  defp handle_delete_scheduled_message_response(response, _attrs),
    do: handle_error_response(response)

  defp handle_delete_message_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(body, "channel"),
       ts: Data.get(body, "ts")
     }}
  end

  defp handle_delete_message_response(response), do: handle_error_response(response)

  defp handle_delete_file_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
       when status in 200..299 do
    {:ok, %{file_id: Data.get(attrs, :file_id)}}
  end

  defp handle_delete_file_response(response, _attrs), do: handle_error_response(response)

  defp handle_add_reaction_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
       when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(attrs, :channel),
       timestamp: Data.get(attrs, :timestamp),
       name: Data.get(attrs, :name)
     }}
  end

  defp handle_add_reaction_response(response, _attrs), do: handle_error_response(response)

  defp handle_remove_reaction_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
       when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(attrs, :channel),
       timestamp: Data.get(attrs, :timestamp),
       name: Data.get(attrs, :name)
     }}
  end

  defp handle_remove_reaction_response(response, _attrs), do: handle_error_response(response)

  defp handle_get_reactions_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}},
         params
       )
       when status in 200..299 do
    with type when is_binary(type) <- Data.get(body, "type"),
         {:ok, target} <- reactions_target(type, body) do
      {:ok,
       target
       |> Map.merge(%{
         type: type,
         channel: Data.get(body, "channel", Data.get(params, :channel)),
         timestamp: Data.get(body, "timestamp", Data.get(params, :timestamp)),
         file_id: Data.get(params, :file),
         file_comment_id: Data.get(params, :file_comment)
       })
       |> Map.put(:reactions, target_reactions(target))
       |> Data.compact()}
    else
      _other -> invalid_success_response("Slack reactions response was invalid", body)
    end
  end

  defp handle_get_reactions_response(response, _params), do: handle_error_response(response)

  defp reactions_target("message", body) do
    case Data.get(body, "message") do
      message when is_map(message) -> {:ok, %{message: message}}
      _other -> {:error, :invalid_target}
    end
  end

  defp reactions_target("file", body) do
    case Data.get(body, "file") do
      file when is_map(file) ->
        {:ok, %{file: file, file_id: Data.get(file, "id")}}

      _other ->
        {:error, :invalid_target}
    end
  end

  defp reactions_target("file_comment", body) do
    with file when is_map(file) <- Data.get(body, "file"),
         file_comment when is_map(file_comment) <- Data.get(body, "comment") do
      {:ok,
       %{
         file: file,
         file_comment: file_comment,
         file_id: Data.get(file, "id"),
         file_comment_id: Data.get(file_comment, "id")
       }}
    else
      _other -> {:error, :invalid_target}
    end
  end

  defp reactions_target(_type, _body), do: {:error, :invalid_target}

  defp target_reactions(%{message: message}), do: Data.get(message, "reactions", [])

  defp target_reactions(%{file_comment: file_comment}),
    do: Data.get(file_comment, "reactions", [])

  defp target_reactions(%{file: file}), do: Data.get(file, "reactions", [])
  defp target_reactions(_target), do: []

  defp invited_users(params, failed_users) do
    failed_user_ids = MapSet.new(failed_users, &Data.get(&1, :user))

    params
    |> Data.get(:users, [])
    |> List.wrap()
    |> Enum.reject(&MapSet.member?(failed_user_ids, &1))
  end

  defp normalize_invite_errors(errors) do
    errors
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn error ->
      %{
        user: Data.get(error, "user"),
        error: Data.get(error, "error"),
        ok: Data.get(error, "ok")
      }
      |> Data.compact()
    end)
  end

  defp normalize_post_at(post_at) when is_integer(post_at), do: post_at

  defp normalize_post_at(post_at) when is_binary(post_at) do
    case Integer.parse(post_at) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp normalize_post_at(_post_at), do: nil

  defp search_total_count(messages) do
    messages
    |> Data.get("pagination", %{})
    |> Data.get("total_count", Data.get(messages, "total"))
  end

  defp handle_upload_url_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    with upload_url when is_binary(upload_url) <- Data.get(body, "upload_url"),
         file_id when is_binary(file_id) <- Data.get(body, "file_id") do
      {:ok, %{upload_url: upload_url, file_id: file_id}}
    else
      _other -> invalid_success_response("Slack upload URL response was invalid", body)
    end
  end

  defp handle_upload_url_response(response), do: handle_error_response(response)

  defp handle_file_content_response({:ok, %{status: status} = response})
       when status in 200..299 do
    {:ok, response}
  end

  defp handle_file_content_response({:ok, %{status: status, body: body}}) do
    Http.provider_error({:ok, %{status: status, body: body}},
      provider: :slack,
      message: "Slack file upload failed"
    )
  end

  defp handle_file_content_response({:error, _reason} = response) do
    Http.provider_error(response, provider: :slack, message: "Slack file upload failed")
  end

  defp handle_complete_upload_response(
         {:ok, %{status: status, body: %{"ok" => true} = body}},
         upload
       )
       when status in 200..299 do
    files = Data.get(body, "files", [])

    if is_list(files) and Enum.all?(files, &is_map/1) do
      {:ok, %{file_id: Data.get(upload, :file_id), files: files}}
    else
      invalid_success_response("Slack complete upload response was invalid", body)
    end
  end

  defp handle_complete_upload_response(response, _upload), do: handle_error_response(response)

  defp handle_share_file_response({:ok, %{status: status, body: %{"ok" => true} = body}}, attrs)
       when status in 200..299 do
    files = Data.get(body, "files", [])

    if is_list(files) and Enum.all?(files, &is_map/1) do
      {:ok, %{file_id: Data.get(attrs, :file_id), files: files}}
    else
      invalid_success_response("Slack share file response was invalid", body)
    end
  end

  defp handle_share_file_response(response, _attrs), do: handle_error_response(response)

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

  defp normalize_conversation(conversation) when is_map(conversation) do
    %{
      id: Data.get(conversation, "id"),
      name: Data.get(conversation, "name"),
      is_im: Data.get(conversation, "is_im"),
      is_mpim: Data.get(conversation, "is_mpim"),
      is_private: Data.get(conversation, "is_private"),
      is_open: Data.get(conversation, "is_open"),
      is_user_deleted: Data.get(conversation, "is_user_deleted"),
      user: Data.get(conversation, "user"),
      users: Data.get(conversation, "users")
    }
    |> Data.compact()
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
