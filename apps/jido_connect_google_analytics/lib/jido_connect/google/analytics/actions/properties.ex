defmodule Jido.Connect.Google.Analytics.Actions.Properties do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/analytics.readonly"
  @scope_resolver Jido.Connect.Google.Analytics.ScopeResolver

  actions do
    action :list_property_summaries do
      id("google.analytics.property_summaries.list")
      resource(:property_summary)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Analytics property summaries")
      description("List Google Analytics properties accessible to the caller.")
      handler(Jido.Connect.Google.Analytics.Handlers.Actions.ListPropertySummaries)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 50)
        field(:page_token, :string)
      end

      output do
        field(:property_summaries, {:array, :map})
        field(:next_page_token, :string)
      end
    end
  end
end
