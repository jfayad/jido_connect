defmodule Jido.Connect.Slack.Client.Reactions do
  @moduledoc "Slack reactions API boundary."

  alias Jido.Connect.Slack.Client.{Params, Response, Transport}

  def add_reaction(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/reactions.add", json: Params.reaction_params(attrs))
    |> Response.handle_add_reaction_response(attrs)
  end

  def remove_reaction(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/reactions.remove", json: Params.reaction_params(attrs))
    |> Response.handle_remove_reaction_response(attrs)
  end

  def get_reactions(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/reactions.get", params: Params.get_reactions_params(params))
    |> Response.handle_get_reactions_response(params)
  end
end
