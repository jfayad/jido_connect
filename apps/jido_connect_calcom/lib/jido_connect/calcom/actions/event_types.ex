defmodule Jido.Connect.Calcom.Actions.EventTypes do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Calcom.ScopeResolver

  actions do
    action :list_event_types do
      id("calcom.event_types.list")
      resource(:event_type)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Cal.com event types")
      description("List available Cal.com event types.")
      handler(Jido.Connect.Calcom.Handlers.Actions.ListEventTypes)
      effect(:read)

      access do
        auth(:api_key)
        scopes(["EVENT_TYPE_READ"], resolver: @scope_resolver)
      end

      input do
        field(:username, :string)
        field(:event_slug, :string)
        field(:org_slug, :string)
        field(:org_id, :integer)
      end

      output do
        field(:event_types, {:array, :map})
      end
    end
  end
end
