defmodule Jido.Connect.Google.SheetsSpike.Normalizer do
  @moduledoc false

  alias Jido.Connect.Data

  def normalize_spreadsheet(spreadsheet) when is_struct(spreadsheet) do
    spreadsheet
    |> Map.from_struct()
    |> normalize_spreadsheet()
  end

  def normalize_spreadsheet(spreadsheet) when is_map(spreadsheet) do
    properties = Data.get(spreadsheet, "properties", %{}) || %{}

    %{
      spreadsheet_id: Data.get(spreadsheet, "spreadsheetId"),
      title: Data.get(properties, "title"),
      sheets: spreadsheet |> Data.get("sheets", []) |> Enum.map(&normalize_sheet/1)
    }
    |> Data.compact()
  end

  defp normalize_sheet(sheet) when is_struct(sheet) do
    sheet
    |> Map.from_struct()
    |> normalize_sheet()
  end

  defp normalize_sheet(sheet) when is_map(sheet) do
    properties = Data.get(sheet, "properties", %{}) || %{}

    %{
      sheet_id: Data.get(properties, "sheetId"),
      title: Data.get(properties, "title"),
      index: Data.get(properties, "index")
    }
    |> Data.compact()
  end
end

defmodule Jido.Connect.Google.SheetsSpike.GeneratedFacade do
  @moduledoc false

  alias Jido.Connect.{CredentialLease, Data, Error}
  alias Jido.Connect.Google.SheetsSpike.Normalizer

  def get_spreadsheet(%CredentialLease{} = lease, spreadsheet_id, opts \\ [])
      when is_binary(spreadsheet_id) and is_list(opts) do
    with {:ok, access_token} <- CredentialLease.fetch_field(lease, :access_token) do
      connection = GoogleApi.Sheets.V4.Connection.new(access_token)

      optional_params =
        []
        |> maybe_put(:ranges, Keyword.get(opts, :ranges))
        |> maybe_put(:includeGridData, Keyword.get(opts, :include_grid_data))

      connection
      |> GoogleApi.Sheets.V4.Api.Spreadsheets.sheets_spreadsheets_get(
        spreadsheet_id,
        optional_params
      )
      |> handle_response()
    else
      :error ->
        {:error,
         Error.auth("Google access token is required",
           reason: :credential_field_required,
           details: %{field: :access_token}
         )}
    end
  end

  defp handle_response({:ok, spreadsheet}) do
    {:ok, Normalizer.normalize_spreadsheet(spreadsheet)}
  end

  defp handle_response({:error, %Tesla.Env{status: status, body: body}}) do
    {:error,
     Error.provider("Google Sheets generated client request failed",
       provider: :google,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: maybe_decode(body)}
     )}
  end

  defp handle_response({:error, reason}) do
    {:error,
     Error.provider("Google Sheets generated client request failed",
       provider: :google,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, []), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)

  defp error_message(body) do
    case maybe_decode(body) do
      %{"error" => %{"message" => message}} -> message
      %{error: %{message: message}} -> message
      _other -> "Google Sheets request failed"
    end
  end

  defp maybe_decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _error} -> body
    end
  end

  defp maybe_decode(body), do: Data.atomize_existing_keys(body)
end

defmodule Jido.Connect.Google.SheetsSpike.ReqFacade do
  @moduledoc false

  alias Jido.Connect.{CredentialLease, Error}
  alias Jido.Connect.Google.{SheetsSpike.Normalizer, Transport}

  def get_spreadsheet(%CredentialLease{} = lease, spreadsheet_id, opts \\ [])
      when is_binary(spreadsheet_id) and is_list(opts) do
    with {:ok, access_token} <- CredentialLease.fetch_field(lease, :access_token) do
      access_token
      |> Transport.request()
      |> Req.get(
        url: "/v4/spreadsheets/#{URI.encode(spreadsheet_id)}",
        params: request_params(opts)
      )
      |> handle_response()
    else
      :error ->
        {:error,
         Error.auth("Google access token is required",
           reason: :credential_field_required,
           details: %{field: :access_token}
         )}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    {:ok, Normalizer.normalize_spreadsheet(body)}
  end

  defp handle_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    Transport.invalid_success_response("Google Sheets spreadsheet response was invalid", body)
  end

  defp handle_response(response), do: Transport.handle_error_response(response)

  defp request_params(opts) do
    []
    |> maybe_put_ranges(Keyword.get(opts, :ranges))
    |> maybe_put(:includeGridData, Keyword.get(opts, :include_grid_data))
  end

  defp maybe_put_ranges(params, nil), do: params
  defp maybe_put_ranges(params, []), do: params

  defp maybe_put_ranges(params, ranges) when is_list(ranges),
    do: params ++ Enum.map(ranges, &{:ranges, &1})

  defp maybe_put_ranges(params, range), do: Keyword.put(params, :ranges, range)

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, []), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)
end
