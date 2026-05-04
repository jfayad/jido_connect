defmodule Jido.Connect.GitHub.Actions.Releases do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_releases do
      id "github.release.list"
      resource :release
      verb :list
      data_classification :workspace_metadata
      label "List releases"
      description "List GitHub releases and repository tags with pagination."
      handler Jido.Connect.GitHub.Handlers.Actions.ListReleases
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :releases, {:array, :map}
        field :tags, {:array, :map}
      end
    end

    action :create_release do
      id "github.release.create"
      resource :release
      verb :create
      data_classification :workspace_content
      label "Create release"

      description "Create a GitHub release with draft, prerelease, latest, and generated notes settings."

      handler Jido.Connect.GitHub.Handlers.Actions.CreateRelease
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :tag_name, :string, required?: true, example: "v1.0.0"
        field :target_commitish, :string
        field :name, :string
        field :body, :string
        field :draft, :boolean, default: false
        field :prerelease, :boolean, default: false
        field :generate_release_notes, :boolean, default: false
        field :make_latest, :string, enum: ["true", "false", "legacy"], default: "true"
      end

      output do
        field :id, :integer
        field :tag_name, :string
        field :name, :string
        field :draft, :boolean
        field :prerelease, :boolean
        field :target_commitish, :string
        field :author, :map
        field :url, :string
        field :upload_url, :string
        field :tarball_url, :string
        field :zipball_url, :string
        field :created_at, :string
        field :published_at, :string
        field :body, :string
      end
    end

    action :upload_release_asset do
      id "github.release_asset.upload"
      resource :release_asset
      verb :upload
      data_classification :workspace_content
      label "Upload release asset"
      description "Upload a GitHub release asset using the release upload URL boundary."
      handler Jido.Connect.GitHub.Handlers.Actions.UploadReleaseAsset
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :upload_url, :string, required?: true
        field :name, :string, required?: true, example: "dist.zip"
        field :label, :string
        field :content_type, :string, required?: true, example: "application/zip"
        field :content_base64, :string, required?: true
      end

      output do
        field :id, :integer
        field :node_id, :string
        field :name, :string
        field :label, :string
        field :state, :string
        field :content_type, :string
        field :size, :integer
        field :download_count, :integer
        field :url, :string
        field :browser_download_url, :string
        field :created_at, :string
        field :updated_at, :string
        field :uploader, :map
      end
    end
  end
end
