defmodule Jido.Connect.Google.SheetsSpikeTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.CredentialLease
  alias Jido.Connect.Google.SheetsSpike.{GeneratedFacade, ReqFacade}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:tesla, :adapter, Tesla.Mock)
    Application.put_env(:google_api_sheets, :base_url, "https://sheets.test/")

    Application.put_env(:jido_connect_google, :google_api_base_url, "https://sheets.test")

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:tesla, :adapter)
      Application.delete_env(:google_api_sheets, :base_url)
      Application.delete_env(:jido_connect_google, :google_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)

    {:ok, lease: lease()}
  end

  test "generated google_api_sheets facade reads and normalizes a spreadsheet", %{lease: lease} do
    Tesla.Mock.mock(fn env ->
      assert env.method == :get
      assert env.url == "https://sheets.test/v4/spreadsheets/sheet123"
      assert {"authorization", "Bearer access"} in env.headers
      assert {:ranges, "Sheet1!A1:B2"} in env.query
      assert {:includeGridData, false} in env.query

      %Tesla.Env{status: 200, body: Jason.encode!(spreadsheet_payload())}
    end)

    assert {:ok, spreadsheet} =
             GeneratedFacade.get_spreadsheet(lease, "sheet123",
               ranges: ["Sheet1!A1:B2"],
               include_grid_data: false
             )

    assert spreadsheet == %{
             spreadsheet_id: "sheet123",
             title: "Budget",
             sheets: [%{sheet_id: 0, title: "Sheet1", index: 0}]
           }
  end

  test "generated google_api_sheets facade returns sanitized provider errors", %{lease: lease} do
    Tesla.Mock.mock(fn _env ->
      %Tesla.Env{
        status: 403,
        body: Jason.encode!(%{"error" => %{"message" => "denied", "secret" => "body"}})
      }
    end)

    assert {:error, error} = GeneratedFacade.get_spreadsheet(lease, "sheet123")
    assert error.provider == :google
    assert error.status == 403
    assert error.details.message == "denied"
    assert error.details.body_summary.type == :map
  end

  test "handwritten Req facade reads and normalizes a spreadsheet", %{lease: lease} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v4/spreadsheets/sheet123"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer access"]
      assert conn.query_params["ranges"] == "Sheet1!A1:B2"
      assert conn.query_params["includeGridData"] == "false"

      Req.Test.json(conn, spreadsheet_payload())
    end)

    assert {:ok, spreadsheet} =
             ReqFacade.get_spreadsheet(lease, "sheet123",
               ranges: ["Sheet1!A1:B2"],
               include_grid_data: false
             )

    assert spreadsheet.title == "Budget"
    assert [%{title: "Sheet1"}] = spreadsheet.sheets
  end

  test "handwritten Req facade returns sanitized provider errors", %{lease: lease} do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{"error" => %{"message" => "denied", "secret" => "body"}})
    end)

    assert {:error, error} = ReqFacade.get_spreadsheet(lease, "sheet123")
    assert error.provider == :google
    assert error.status == 403
    assert error.details.message == "denied"
    assert error.details.body_summary.type == :map
  end

  defp lease do
    CredentialLease.new!(%{
      connection_id: "conn_1",
      provider: :google,
      profile: :user,
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      fields: %{access_token: "access"}
    })
  end

  defp spreadsheet_payload do
    %{
      "spreadsheetId" => "sheet123",
      "properties" => %{"title" => "Budget"},
      "sheets" => [
        %{
          "properties" => %{
            "sheetId" => 0,
            "title" => "Sheet1",
            "index" => 0
          }
        }
      ]
    }
  end
end
