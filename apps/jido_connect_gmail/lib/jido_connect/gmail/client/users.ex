defmodule Jido.Connect.Gmail.Client.Users do
  @moduledoc "Gmail users API boundary."

  alias Jido.Connect.Gmail.Client.{Response, Transport}

  def get_profile(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/profile")
    |> Response.handle_profile_response()
  end

  def list_labels(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/labels")
    |> Response.handle_label_list_response()
  end
end
