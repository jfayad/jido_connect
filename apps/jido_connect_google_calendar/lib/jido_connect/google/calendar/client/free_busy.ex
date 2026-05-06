defmodule Jido.Connect.Google.Calendar.Client.FreeBusy do
  @moduledoc "Google Calendar freeBusy API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def query_free_busy(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/v3/freeBusy", json: Params.free_busy_body(params))
    |> Response.handle_free_busy_response()
  end
end
