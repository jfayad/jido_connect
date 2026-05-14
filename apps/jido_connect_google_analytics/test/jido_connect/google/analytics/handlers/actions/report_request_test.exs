defmodule Jido.Connect.Google.Analytics.Handlers.Actions.ReportRequestTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Analytics.Handlers.Actions.ReportRequest

  test "normalizes run report input into Google Analytics request JSON" do
    assert {:ok, %{property: "properties/1234", body: body}} =
             ReportRequest.run_report_input(%{
               property: " 1234 ",
               date_ranges: [%{start_date: "7daysAgo", end_date: "yesterday", name: "last7"}],
               dimensions: ["country"],
               metrics: ["activeUsers"],
               dimension_filter: %{
                 filter: %{
                   field_name: "country",
                   string_filter: %{match_type: "EXACT", value: "US"}
                 }
               },
               metric_filter: %{
                 filter: %{
                   field_name: "activeUsers",
                   numeric_filter: %{operation: "GREATER_THAN", value: %{int64_value: "0"}}
                 }
               },
               order_bys: [%{metric: %{metric_name: "activeUsers"}, desc: true}],
               metric_aggregations: ["TOTAL"],
               limit: 100,
               offset: "0",
               currency_code: "USD",
               keep_empty_rows: false,
               return_property_quota: true
             })

    assert body == %{
             "dateRanges" => [
               %{"startDate" => "7daysAgo", "endDate" => "yesterday", "name" => "last7"}
             ],
             "dimensions" => [%{"name" => "country"}],
             "metrics" => [%{"name" => "activeUsers"}],
             "dimensionFilter" => %{
               "filter" => %{
                 "fieldName" => "country",
                 "stringFilter" => %{"matchType" => "EXACT", "value" => "US"}
               }
             },
             "metricFilter" => %{
               "filter" => %{
                 "fieldName" => "activeUsers",
                 "numericFilter" => %{
                   "operation" => "GREATER_THAN",
                   "value" => %{"int64Value" => "0"}
                 }
               }
             },
             "orderBys" => [%{"metric" => %{"metricName" => "activeUsers"}, "desc" => true}],
             "metricAggregations" => ["TOTAL"],
             "limit" => "100",
             "offset" => "0",
             "currencyCode" => "USD",
             "keepEmptyRows" => false,
             "returnPropertyQuota" => true
           }
  end

  test "supports provider metric maps" do
    assert {:ok,
            %{body: %{"metrics" => [%{"name" => "eventValue", "expression" => "eventCount * 2"}]}}} =
             ReportRequest.run_report_input(%{
               property: "properties/1234",
               date_ranges: [%{startDate: "2026-05-01", endDate: "2026-05-14"}],
               metrics: [%{name: "eventValue", expression: "eventCount * 2"}]
             })
  end

  test "validates run report shape" do
    invalid_inputs = [
      %{property: "properties/1234", metrics: ["activeUsers"]},
      %{property: "properties/1234", date_ranges: [], metrics: ["activeUsers"]},
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "bad", end_date: "today"}],
        metrics: ["activeUsers"]
      },
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
        metrics: []
      },
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
        metrics: Enum.map(1..11, &"metric#{&1}")
      },
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
        metrics: ["activeUsers"],
        dimensions: Enum.map(1..10, &"dimension#{&1}")
      },
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
        metrics: ["activeUsers"],
        dimension_filter: "bad"
      },
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
        metrics: ["activeUsers"],
        limit: 0
      },
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
        metrics: ["activeUsers"],
        limit: 250_001
      },
      %{
        property: "properties/1234",
        date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
        metrics: ["activeUsers"],
        offset: -1
      }
    ]

    for input <- invalid_inputs do
      assert {:error, %Error.ValidationError{reason: :invalid_report_request}} =
               ReportRequest.run_report_input(input)
    end
  end

  test "normalizes and validates batch report input" do
    assert {:ok, %{property: "properties/1234", body: body}} =
             ReportRequest.batch_run_reports_input(%{
               property: "1234",
               requests: [
                 %{
                   property: "properties/1234",
                   date_ranges: [%{start_date: "7daysAgo", end_date: "yesterday"}],
                   metrics: ["activeUsers"],
                   dimensions: ["country"]
                 }
               ]
             })

    assert body == %{
             "requests" => [
               %{
                 "dateRanges" => [%{"startDate" => "7daysAgo", "endDate" => "yesterday"}],
                 "dimensions" => [%{"name" => "country"}],
                 "metrics" => [%{"name" => "activeUsers"}]
               }
             ]
           }

    assert {:error, %Error.ValidationError{reason: :invalid_report_request}} =
             ReportRequest.batch_run_reports_input(%{property: "1234", requests: []})

    assert {:error, %Error.ValidationError{reason: :invalid_report_request}} =
             ReportRequest.batch_run_reports_input(%{
               property: "1234",
               requests:
                 Enum.map(1..6, fn _index ->
                   %{
                     date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
                     metrics: ["activeUsers"]
                   }
                 end)
             })

    assert {:error, %Error.ValidationError{reason: :invalid_report_request}} =
             ReportRequest.batch_run_reports_input(%{
               property: "1234",
               requests: [
                 %{
                   property: "properties/5678",
                   date_ranges: [%{start_date: "7daysAgo", end_date: "today"}],
                   metrics: ["activeUsers"]
                 }
               ]
             })
  end

  test "normalizes realtime report input into Google Analytics request JSON" do
    assert {:ok, %{property: "properties/1234", body: body}} =
             ReportRequest.realtime_report_input(%{
               property: " 1234 ",
               dimensions: ["city"],
               metrics: ["activeUsers"],
               dimension_filter: %{
                 filter: %{
                   field_name: "city",
                   string_filter: %{match_type: "EXACT", value: "Chicago"}
                 }
               },
               metric_filter: %{
                 filter: %{
                   field_name: "activeUsers",
                   numeric_filter: %{operation: "GREATER_THAN", value: %{int64_value: "0"}}
                 }
               },
               limit: "25",
               metric_aggregations: ["TOTAL"],
               order_bys: [%{metric: %{metric_name: "activeUsers"}, desc: true}],
               return_property_quota: true,
               minute_ranges: [%{name: "last30", start_minutes_ago: 29, end_minutes_ago: 0}]
             })

    assert body == %{
             "dimensions" => [%{"name" => "city"}],
             "metrics" => [%{"name" => "activeUsers"}],
             "dimensionFilter" => %{
               "filter" => %{
                 "fieldName" => "city",
                 "stringFilter" => %{"matchType" => "EXACT", "value" => "Chicago"}
               }
             },
             "metricFilter" => %{
               "filter" => %{
                 "fieldName" => "activeUsers",
                 "numericFilter" => %{
                   "operation" => "GREATER_THAN",
                   "value" => %{"int64Value" => "0"}
                 }
               }
             },
             "limit" => "25",
             "metricAggregations" => ["TOTAL"],
             "orderBys" => [%{"metric" => %{"metricName" => "activeUsers"}, "desc" => true}],
             "returnPropertyQuota" => true,
             "minuteRanges" => [
               %{"name" => "last30", "startMinutesAgo" => 29, "endMinutesAgo" => 0}
             ]
           }
  end

  test "validates realtime report shape" do
    invalid_inputs = [
      %{property: "properties/1234", minute_ranges: [%{start_minutes_ago: 29}]},
      %{property: "properties/1234", metrics: []},
      %{property: "properties/1234", metrics: ["activeUsers"], minute_ranges: "bad"},
      %{
        property: "properties/1234",
        metrics: ["activeUsers"],
        minute_ranges: [%{start_minutes_ago: 60, end_minutes_ago: 0}]
      },
      %{
        property: "properties/1234",
        metrics: ["activeUsers"],
        minute_ranges: [%{start_minutes_ago: 0, end_minutes_ago: 29}]
      },
      %{
        property: "properties/1234",
        metrics: ["activeUsers"],
        minute_ranges: [
          %{start_minutes_ago: 29, end_minutes_ago: 20},
          %{start_minutes_ago: 19, end_minutes_ago: 10},
          %{start_minutes_ago: 9, end_minutes_ago: 0}
        ]
      },
      %{
        property: "properties/1234",
        metrics: ["activeUsers"],
        minute_ranges: [%{name: "RESERVED_total", start_minutes_ago: 29, end_minutes_ago: 0}]
      }
    ]

    for input <- invalid_inputs do
      assert {:error, %Error.ValidationError{reason: reason}} =
               ReportRequest.realtime_report_input(input)

      assert reason in [:invalid_report_request, :invalid_realtime_report_request]
    end
  end
end
