defmodule Jido.Connect.Calcom.Client.Bookings do
  @moduledoc "Cal.com bookings API boundary."

  alias Jido.Connect.Calcom.Client.{Response, Transport}

  def list_bookings(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:bookings_list))
    |> Req.get(
      url: "/v2/bookings",
      params: list_params(params)
    )
    |> Response.handle_list_bookings_response()
  end

  def get_booking(%{booking_uid: booking_uid}, access_token)
      when is_binary(booking_uid) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:bookings_detail))
    |> Req.get(url: "/v2/bookings/#{URI.encode(booking_uid)}")
    |> Response.handle_get_booking_response()
  end

  def cancel_booking(%{booking_uid: booking_uid, body: body}, access_token)
      when is_binary(booking_uid) and is_map(body) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:bookings_detail))
    |> Req.post(
      url: "/v2/bookings/#{URI.encode(booking_uid)}/cancel",
      json: body
    )
    |> Response.handle_cancel_booking_response()
  end

  def reschedule_booking(%{booking_uid: booking_uid, body: body}, access_token)
      when is_binary(booking_uid) and is_map(body) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:bookings_detail))
    |> Req.post(
      url: "/v2/bookings/#{URI.encode(booking_uid)}/reschedule",
      json: body
    )
    |> Response.handle_reschedule_booking_response()
  end

  defp list_params(params) do
    params
    |> Map.take([
      :status,
      :attendee_email,
      :event_type_id,
      :after_start,
      :before_end,
      :cursor,
      :limit
    ])
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new(fn
      {:status, value} -> {"status", value}
      {:attendee_email, value} -> {"attendeeEmail", value}
      {:event_type_id, value} -> {"eventTypeId", value}
      {:after_start, value} -> {"afterStart", value}
      {:before_end, value} -> {"beforeEnd", value}
      {:cursor, value} -> {"cursor", value}
      {:limit, value} -> {"limit", value}
    end)
  end
end
