defmodule Jido.Connect.Slack.Client.Messages do
  @moduledoc "Slack message and message-search API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Client.{Params, Response, Transport}

  def post_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/chat.postMessage", json: Data.compact(attrs))
    |> Response.handle_message_response()
  end

  def post_ephemeral(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/chat.postEphemeral", json: Params.ephemeral_message_params(attrs))
    |> Response.handle_ephemeral_message_response(attrs)
  end

  def schedule_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/chat.scheduleMessage", json: Params.scheduled_message_params(attrs))
    |> Response.handle_scheduled_message_response()
  end

  def delete_scheduled_message(attrs, access_token)
      when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/chat.deleteScheduledMessage",
      json: Params.delete_scheduled_message_params(attrs)
    )
    |> Response.handle_delete_scheduled_message_response(attrs)
  end

  def update_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/chat.update", json: Data.compact(attrs))
    |> Response.handle_message_response()
  end

  def delete_message(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/chat.delete", json: Data.compact(attrs))
    |> Response.handle_delete_message_response()
  end

  def get_thread_replies(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/conversations.replies", params: Params.thread_replies_params(params))
    |> Response.handle_thread_replies_response(params)
  end

  def search_messages(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/search.messages", params: Params.search_messages_params(params))
    |> Response.handle_search_messages_response()
  end
end
