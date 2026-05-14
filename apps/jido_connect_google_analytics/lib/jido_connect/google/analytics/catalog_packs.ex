defmodule Jido.Connect.Google.Analytics.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Analytics tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "google.analytics.metadata.get",
    "google.analytics.property_summaries.list"
  ]

  @reporter_tools @reader_tools ++
                    [
                      "google.analytics.report.run",
                      "google.analytics.report.batch_run",
                      "google.analytics.report.realtime.run"
                    ]

  @doc "Returns all built-in Google Analytics catalog packs."
  def all, do: [reader(), reporter()]

  @doc "Read-only Analytics discovery pack for metadata and property summaries."
  def reader do
    Pack.new!(%{
      id: :google_analytics_reader,
      label: "Google Analytics reader",
      description:
        "Read GA4 metadata and property summaries without report execution or mutation tools.",
      filters: %{provider: :google_analytics},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_google_analytics, risk: :read}
    })
  end

  @doc "Analytics reporting pack for metadata, property discovery, and GA4 reports."
  def reporter do
    Pack.new!(%{
      id: :google_analytics_reporter,
      label: "Google Analytics reporter",
      description:
        "Read Analytics metadata, discover GA4 properties, and run standard, batch, or realtime reports.",
      filters: %{provider: :google_analytics},
      allowed_tools: @reporter_tools,
      metadata: %{package: :jido_connect_google_analytics, risk: :read}
    })
  end
end
