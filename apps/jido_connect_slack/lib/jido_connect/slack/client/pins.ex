defmodule Jido.Connect.Slack.Client.Pins do
  @moduledoc "Slack pins API boundary."

  alias Jido.Connect.Slack.Client.{Params, Response, Transport}

  def list_pins(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/pins.list", params: Params.pin_list_params(params))
    |> Response.handle_pin_list_response(params)
  end

  def add_pin(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/pins.add", json: Params.pin_params(attrs))
    |> Response.handle_add_pin_response(attrs)
  end

  def remove_pin(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/pins.remove", json: Params.pin_params(attrs))
    |> Response.handle_remove_pin_response(attrs)
  end
end
