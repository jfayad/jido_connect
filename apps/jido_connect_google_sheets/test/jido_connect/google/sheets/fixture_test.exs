defmodule Jido.Connect.Google.Sheets.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Sheets.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes common Google Sheets spreadsheet fixture" do
    payload = fixture!("spreadsheet_common.json")

    assert {:ok, spreadsheet} = Normalizer.spreadsheet(payload)
    assert spreadsheet.spreadsheet_id == "sheet123"
    assert spreadsheet.title == "Budget"
    assert spreadsheet.locale == "en_US"

    assert [%{sheet_id: 0, title: "Summary", row_count: 1000, column_count: 26}] =
             spreadsheet.sheets
  end

  test "normalizes edge Google Sheets value range fixture" do
    payload = fixture!("value_range_edge.json")

    assert {:ok, value_range} = Normalizer.value_range(payload)
    assert value_range.range == "Summary!A1:C3"
    assert value_range.major_dimension == "ROWS"

    assert value_range.values == [
             ["Name", "Amount", "Notes"],
             ["Budget", 10, ""],
             ["Forecast", nil, "Missing amount"]
           ]
  end

  defp fixture!(name) do
    "../../../fixtures/google_sheets/#{name}"
    |> Path.expand(__DIR__)
    |> ConnectorContracts.json_fixture!()
  end
end
