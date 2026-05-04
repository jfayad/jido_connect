defmodule Jido.Connect.Google.Sheets.Client.Values do
  @moduledoc "Google Sheets values API boundary."

  alias Jido.Connect.Google.Sheets.Client.{Params, Response, Transport}

  def get_values(%{spreadsheet_id: spreadsheet_id, range: range} = params, access_token)
      when is_binary(spreadsheet_id) and is_binary(range) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url:
        "/v4/spreadsheets/#{encode_path_segment(spreadsheet_id)}/values/#{encode_path_segment(range)}",
      params: Params.values_get_params(params)
    )
    |> Response.handle_value_range_response()
  end

  def update_values(%{spreadsheet_id: spreadsheet_id, range: range} = params, access_token)
      when is_binary(spreadsheet_id) and is_binary(range) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: values_url(spreadsheet_id, range),
      params: Params.values_update_params(params),
      json: value_range_body(params)
    )
    |> Response.handle_update_result_response()
  end

  def append_values(%{spreadsheet_id: spreadsheet_id, range: range} = params, access_token)
      when is_binary(spreadsheet_id) and is_binary(range) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: values_url(spreadsheet_id, range) <> ":append",
      params: Params.values_append_params(params),
      json: value_range_body(params)
    )
    |> Response.handle_update_result_response()
  end

  def clear_values(%{spreadsheet_id: spreadsheet_id, range: range}, access_token)
      when is_binary(spreadsheet_id) and is_binary(range) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: values_url(spreadsheet_id, range) <> ":clear", json: %{})
    |> Response.handle_update_result_response()
  end

  defp values_url(spreadsheet_id, range) do
    "/v4/spreadsheets/#{encode_path_segment(spreadsheet_id)}/values/#{encode_path_segment(range)}"
  end

  defp value_range_body(params) do
    %{
      range: Map.get(params, :range),
      majorDimension: Map.get(params, :major_dimension, "ROWS"),
      values: Map.get(params, :values, [])
    }
  end

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
