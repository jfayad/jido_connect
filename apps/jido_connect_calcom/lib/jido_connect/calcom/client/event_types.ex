defmodule Jido.Connect.Calcom.Client.EventTypes do
  @moduledoc "Cal.com event types API boundary."

  alias Jido.Connect.Calcom.Client.{Response, Transport}

  def list_event_types(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:event_types))
    |> Req.get(
      url: "/v2/event-types",
      params: list_params(params)
    )
    |> Response.handle_event_types_response()
  end

  defp list_params(params) do
    params
    |> Map.take([:username, :event_slug, :org_slug, :org_id])
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new(fn
      {:username, value} -> {"username", value}
      {:event_slug, value} -> {"eventSlug", value}
      {:org_slug, value} -> {"orgSlug", value}
      {:org_id, value} -> {"orgId", value}
    end)
  end
end
