defmodule Jido.Connect.Google.Analytics.Client.PropertySummaries do
  @moduledoc "Google Analytics Admin API property summary boundary."

  alias Jido.Connect.Google.Analytics.Client.{Response, Transport}

  def list_property_summaries(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.admin_request()
    |> Req.get(
      url: "/v1beta/accountSummaries",
      params: list_params(params)
    )
    |> Response.handle_property_summaries_response()
  end

  defp list_params(params) do
    params
    |> Map.take([:page_size, :page_token])
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new(fn
      {:page_size, value} -> {"pageSize", value}
      {:page_token, value} -> {"pageToken", value}
    end)
  end
end
