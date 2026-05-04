defmodule Jido.Connect.Slack.Client.Identity do
  @moduledoc "Slack auth and team metadata API boundary."

  alias Jido.Connect.Slack.Client.{Params, Response, Transport}

  def auth_test(access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/auth.test")
    |> Response.handle_map_response()
  end

  def team_info(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/team.info", params: Params.team_info_params(params))
    |> Response.handle_team_info_response()
  end
end
