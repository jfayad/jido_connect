defmodule Jido.Connect.Google.Analytics.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Analytics

  @analytics_readonly_scope "https://www.googleapis.com/auth/analytics.readonly"

  defmodule FakeAnalyticsClient do
    def run_report(%{property: "properties/1234"}, "token") do
      {:ok,
       Analytics.Report.new!(%{
         metric_headers: [Analytics.Metric.new!(%{name: "activeUsers", type: "TYPE_INTEGER"})],
         rows: [
           Analytics.Row.new!(%{
             metrics: [
               Analytics.Metric.new!(%{name: "activeUsers", value: "42", type: "TYPE_INTEGER"})
             ]
           })
         ],
         row_count: 1
       })}
    end
  end

  test "reader pack restricts search and describe to discovery tools" do
    results =
      Catalog.search_tools("analytics",
        modules: [Analytics],
        packs: Analytics.catalog_packs(),
        pack: :google_analytics_reader
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.analytics.metadata.get" in ids
    assert "google.analytics.property_summaries.list" in ids
    refute "google.analytics.report.run" in ids
    refute "google.analytics.report.batch_run" in ids
    refute "google.analytics.report.realtime.run" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.analytics.property_summaries.list",
               modules: [Analytics],
               packs: Analytics.catalog_packs(),
               pack: :google_analytics_reader
             )

    assert descriptor.tool.id == "google.analytics.property_summaries.list"
    assert Analytics.reader_pack().metadata.risk == :read

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.analytics.report.run",
               modules: [Analytics],
               packs: Analytics.catalog_packs(),
               pack: :google_analytics_reader
             )
  end

  test "reporter pack allows discovery and report execution tools" do
    results =
      Catalog.search_tools("report",
        modules: [Analytics],
        packs: Analytics.catalog_packs(),
        pack: :google_analytics_reporter
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.analytics.report.run" in ids
    assert "google.analytics.report.batch_run" in ids
    assert "google.analytics.report.realtime.run" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.analytics.metadata.get",
               modules: [Analytics],
               packs: Analytics.catalog_packs(),
               pack: :google_analytics_reporter
             )

    assert descriptor.tool.id == "google.analytics.metadata.get"
    assert Analytics.reporter_pack().metadata.risk == :read
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    input = %{
      property: "1234",
      date_ranges: [%{start_date: "7daysAgo", end_date: "yesterday"}],
      metrics: ["activeUsers"]
    }

    assert {:ok, %{report: %{row_count: 1}}} =
             Catalog.call_tool(
               "google.analytics.report.run",
               input,
               modules: [Analytics],
               packs: Analytics.catalog_packs(),
               pack: :google_analytics_reporter,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.analytics.report.run",
               input,
               modules: [Analytics],
               packs: Analytics.catalog_packs(),
               pack: :google_analytics_reader,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease do
    scopes = [
      "openid",
      "email",
      "profile",
      @analytics_readonly_scope
    ]

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
