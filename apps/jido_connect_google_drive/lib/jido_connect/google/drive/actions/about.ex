defmodule Jido.Connect.Google.Drive.Actions.About do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :get_about do
      id("google.drive.about.get")
      resource(:drive)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get Drive account metadata")
      description("Fetch Google Drive user, quota, and system capability metadata.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetAbout)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:fields, :string,
          description: "Google Drive about.get fields expression.",
          metadata: %{presets: Fields.about_presets()}
        )
      end

      output do
        field(:about, :map)
      end
    end
  end
end
