defmodule Jido.Connect.Google.Calendar.Client.Events do
  @moduledoc "Google Calendar events API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def list_events(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events",
      params: Params.list_events_params(params)
    )
    |> Response.handle_event_list_response(params)
  end

  def get_event(%{calendar_id: calendar_id, event_id: event_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(event_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events/#{encode_id(event_id)}",
      params: Params.get_event_params(params)
    )
    |> Response.handle_event_response(params)
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
