defmodule Jido.Connect.GitHub.Client.Installations do
  @moduledoc "GitHub installation metadata API boundary."

  alias Jido.Connect.GitHub.Client.{Response, Transport}

  def fetch_installation(installation_id, access_token) when is_integer(installation_id) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/app/installations/#{installation_id}")
    |> Response.handle_map_response()
  end
end
