defmodule Jido.Connect.Slack.Client.Users do
  @moduledoc "Slack users API boundary."

  alias Jido.Connect.Slack.Client.{Params, Response, Transport}

  def list_users(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/users.list", params: Params.list_users_params(params))
    |> Response.handle_user_list_response()
  end

  def user_info(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/users.info", params: Params.user_info_params(params))
    |> Response.handle_user_info_response()
  end

  def lookup_user_by_email(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/users.lookupByEmail", params: Params.lookup_user_by_email_params(params))
    |> Response.handle_lookup_user_by_email_response()
  end
end
