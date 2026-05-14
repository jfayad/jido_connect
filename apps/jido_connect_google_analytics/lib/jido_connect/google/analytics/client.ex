defmodule Jido.Connect.Google.Analytics.Client do
  @moduledoc "Google Analytics API client boundary."

  alias Jido.Connect.Google.Analytics.Client.{Metadata, PropertySummaries, Reports}

  defdelegate get_metadata(params, access_token), to: Metadata
  defdelegate run_report(params, access_token), to: Reports
  defdelegate batch_run_reports(params, access_token), to: Reports
  defdelegate run_realtime_report(params, access_token), to: Reports
  defdelegate list_property_summaries(params, access_token), to: PropertySummaries
end
