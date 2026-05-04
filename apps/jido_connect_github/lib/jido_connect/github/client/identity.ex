defmodule Jido.Connect.GitHub.Client.Identity do
  @moduledoc "GitHub authenticated-user API boundary."

  alias Jido.Connect.GitHub.Client.{Response, Transport}

  def fetch_authenticated_user(access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/user")
    |> Response.handle_map_response()
  end
end
