defmodule Jido.Connect.Slack.Client.Conversations do
  @moduledoc "Slack Conversations API boundary."

  alias Jido.Connect.Slack.Client.{Params, Response, Transport}

  def list_channels(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/conversations.list", params: Params.list_channels_params(params))
    |> Response.handle_channel_list_response()
  end

  def get_conversation_info(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/conversations.info", params: Params.conversation_info_params(params))
    |> Response.handle_conversation_info_response(params)
  end

  def create_channel(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.create", json: Params.create_channel_params(params))
    |> Response.handle_create_channel_response()
  end

  def archive_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.archive", json: Params.archive_conversation_params(params))
    |> Response.handle_archive_conversation_response(params)
  end

  def unarchive_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/conversations.unarchive",
      json: Params.unarchive_conversation_params(params)
    )
    |> Response.handle_unarchive_conversation_response(params)
  end

  def rename_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.rename", json: Params.rename_conversation_params(params))
    |> Response.handle_rename_conversation_response()
  end

  def invite_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.invite", json: Params.invite_conversation_params(params))
    |> Response.handle_invite_conversation_response(params)
  end

  def kick_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.kick", json: Params.kick_conversation_params(params))
    |> Response.handle_kick_conversation_response(params)
  end

  def open_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.open", json: Params.open_conversation_params(params))
    |> Response.handle_open_conversation_response()
  end

  def list_conversation_members(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/conversations.members", params: Params.conversation_members_params(params))
    |> Response.handle_conversation_members_response(params)
  end
end
