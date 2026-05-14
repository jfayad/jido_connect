defmodule Jido.Connect.Google.AnalyticsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Analytics
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @analytics_readonly_scope "https://www.googleapis.com/auth/analytics.readonly"
  @analytics_action_modules [
    Jido.Connect.Google.Analytics.Actions.GetMetadata,
    Jido.Connect.Google.Analytics.Actions.RunReport,
    Jido.Connect.Google.Analytics.Actions.BatchRunReports,
    Jido.Connect.Google.Analytics.Actions.RunRealtimeReport,
    Jido.Connect.Google.Analytics.Actions.ListPropertySummaries
  ]
  @analytics_dsl_fragments [
    Jido.Connect.Google.Analytics.Actions.Metadata,
    Jido.Connect.Google.Analytics.Actions.Reports,
    Jido.Connect.Google.Analytics.Actions.Properties
  ]

  defmodule FakeAnalyticsClient do
    def get_metadata(%{property: "properties/1234"}, "token") do
      {:ok,
       %{
         metadata_name: "properties/1234/metadata",
         dimensions: [
           Analytics.Dimension.new!(%{
             name: "country",
             display_name: "Country",
             category: "Geography"
           })
         ],
         metrics: [
           Analytics.Metric.new!(%{
             name: "activeUsers",
             display_name: "Active users",
             type: "TYPE_INTEGER"
           })
         ],
         comparisons: []
       }}
    end

    def run_report(%{property: "properties/1234"}, "token") do
      {:ok,
       Analytics.Report.new!(%{
         dimension_headers: [Analytics.Dimension.new!(%{name: "country"})],
         metric_headers: [Analytics.Metric.new!(%{name: "activeUsers", type: "TYPE_INTEGER"})],
         rows: [
           Analytics.Row.new!(%{
             dimensions: [Analytics.Dimension.new!(%{name: "country", value: "US"})],
             metrics: [
               Analytics.Metric.new!(%{name: "activeUsers", value: "42", type: "TYPE_INTEGER"})
             ]
           })
         ],
         row_count: 1
       })}
    end

    def batch_run_reports(%{property: "properties/1234"}, "token") do
      {:ok,
       %{
         kind: "analyticsData#batchRunReports",
         reports: [
           Analytics.Report.new!(%{
             metric_headers: [Analytics.Metric.new!(%{name: "activeUsers"})],
             row_count: 0
           })
         ]
       }}
    end

    def run_realtime_report(%{property: "properties/1234"}, "token") do
      {:ok,
       Analytics.Report.new!(%{
         kind: "analyticsData#runRealtimeReport",
         dimension_headers: [Analytics.Dimension.new!(%{name: "city"})],
         metric_headers: [Analytics.Metric.new!(%{name: "activeUsers", type: "TYPE_INTEGER"})],
         rows: [
           Analytics.Row.new!(%{
             dimensions: [Analytics.Dimension.new!(%{name: "city", value: "Chicago"})],
             metrics: [
               Analytics.Metric.new!(%{name: "activeUsers", value: "7", type: "TYPE_INTEGER"})
             ]
           })
         ],
         row_count: 1
       })}
    end

    def list_property_summaries(%{page_size: 50}, "token") do
      {:ok,
       %{
         property_summaries: [
           Analytics.PropertySummary.new!(%{
             property: "properties/1234",
             display_name: "Jido Web",
             property_type: "PROPERTY_TYPE_ORDINARY",
             parent: "accounts/1000",
             account: "accounts/1000"
           })
         ],
         next_page_token: "next"
       }}
    end
  end

  test "declares Google Analytics provider metadata" do
    spec = Analytics.integration()

    assert spec.id == :google_analytics
    assert spec.package == :jido_connect_google_analytics
    assert spec.name == "Google Analytics"
    assert spec.category == :marketing
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :analytics, :reporting]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.analytics.metadata.get",
             "google.analytics.report.run",
             "google.analytics.report.batch_run",
             "google.analytics.report.realtime.run",
             "google.analytics.property_summaries.list"
           ]

    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @analytics_readonly_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Analytics,
      otp_app: :jido_connect_google_analytics,
      action_modules: @analytics_action_modules,
      plugin_module: Jido.Connect.Google.Analytics.Plugin,
      plugin_name: "google_analytics"
    )

    ConnectorContracts.assert_plugin_tool_availability(Analytics)
  end

  test "loads Analytics Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@analytics_dsl_fragments)
  end

  test "exposes curated catalog pack delegates" do
    ConnectorContracts.assert_catalog_pack_delegates(Analytics,
      reader_pack: :google_analytics_reader,
      reporter_pack: :google_analytics_reporter
    )

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Analytics,
      id_prefix: "google.analytics.",
      pack_id_prefix: "google_analytics_",
      module_namespace: Jido.Connect.Google.Analytics
    )
  end

  test "invokes get metadata through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@analytics_readonly_scope])

    assert {:ok,
            %{
              metadata_name: "properties/1234/metadata",
              dimensions: [%{name: "country", display_name: "Country"}],
              metrics: [%{name: "activeUsers", type: "TYPE_INTEGER"}],
              comparisons: []
            }} =
             Connect.invoke(
               Analytics.integration(),
               "google.analytics.metadata.get",
               %{property: "1234"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes run report through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@analytics_readonly_scope])

    assert {:ok,
            %{
              report: %{
                row_count: 1,
                rows: [
                  %{
                    dimensions: [%{name: "country", value: "US"}],
                    metrics: [%{name: "activeUsers", value: "42", type: "TYPE_INTEGER"}]
                  }
                ]
              }
            }} =
             Connect.invoke(
               Analytics.integration(),
               "google.analytics.report.run",
               %{
                 property: "1234",
                 date_ranges: [%{start_date: "7daysAgo", end_date: "yesterday"}],
                 metrics: ["activeUsers"],
                 dimensions: ["country"]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch run reports through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@analytics_readonly_scope])

    assert {:ok,
            %{
              kind: "analyticsData#batchRunReports",
              reports: [%{row_count: 0, metric_headers: [%{name: "activeUsers"}]}]
            }} =
             Connect.invoke(
               Analytics.integration(),
               "google.analytics.report.batch_run",
               %{
                 property: "1234",
                 requests: [
                   %{
                     date_ranges: [%{start_date: "7daysAgo", end_date: "yesterday"}],
                     metrics: ["activeUsers"]
                   }
                 ]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes realtime report through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@analytics_readonly_scope])

    assert {:ok,
            %{
              report: %{
                kind: "analyticsData#runRealtimeReport",
                row_count: 1,
                rows: [
                  %{
                    dimensions: [%{name: "city", value: "Chicago"}],
                    metrics: [%{name: "activeUsers", value: "7", type: "TYPE_INTEGER"}]
                  }
                ]
              }
            }} =
             Connect.invoke(
               Analytics.integration(),
               "google.analytics.report.realtime.run",
               %{
                 property: "1234",
                 metrics: ["activeUsers"],
                 dimensions: ["city"],
                 minute_ranges: [%{start_minutes_ago: 29, end_minutes_ago: 0}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes property summary listing through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@analytics_readonly_scope])

    assert {:ok,
            %{
              property_summaries: [
                %{
                  property: "properties/1234",
                  display_name: "Jido Web",
                  property_type: "PROPERTY_TYPE_ORDINARY",
                  account: "accounts/1000"
                }
              ],
              next_page_token: "next"
            }} =
             Connect.invoke(
               Analytics.integration(),
               "google.analytics.property_summaries.list",
               %{page_size: 50},
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease(opts) do
    scopes = Keyword.get(opts, :scopes, [@analytics_readonly_scope])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_analytics_client: FakeAnalyticsClient},
        scopes: scopes
      })

    {context, lease}
  end
end
