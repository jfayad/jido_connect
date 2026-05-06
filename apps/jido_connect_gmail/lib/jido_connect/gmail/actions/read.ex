defmodule Jido.Connect.Gmail.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @scope_resolver Jido.Connect.Gmail.ScopeResolver

  actions do
    action :get_profile do
      id("google.gmail.profile.get")
      resource(:profile)
      verb(:get)
      data_classification(:personal_data)
      label("Get Gmail profile")
      description("Fetch Gmail mailbox profile metadata for the authenticated user.")
      handler(Jido.Connect.Gmail.Handlers.Actions.GetProfile)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:profile, :map)
      end
    end

    action :list_labels do
      id("google.gmail.labels.list")
      resource(:label)
      verb(:list)
      data_classification(:personal_data)
      label("List Gmail labels")
      description("List Gmail labels for the authenticated user.")
      handler(Jido.Connect.Gmail.Handlers.Actions.ListLabels)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:labels, {:array, :map})
      end
    end
  end
end
