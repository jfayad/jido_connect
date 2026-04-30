defmodule Jido.Connect.GitHub.Actions.Repositories do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_repositories do
      id "github.repo.list"
      resource :repository
      verb :list
      data_classification :workspace_metadata
      label "List repositories"
      description "List GitHub repositories visible to the connection."
      handler Jido.Connect.GitHub.Handlers.Actions.ListRepositories
      effect :read

      access do
        auth [:user, :installation], default: :user
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :repositories, {:array, :map}
        field :total_count, :integer
      end
    end

    action :list_installation_repositories do
      id "github.installation_repository.list"
      resource :repository
      verb :list
      data_classification :workspace_metadata
      label "List installation repositories"

      description "List repositories accessible to a GitHub App installation and its granted permissions."

      handler Jido.Connect.GitHub.Handlers.Actions.ListInstallationRepositories
      effect :read

      access do
        auth [:installation], default: :installation
        scopes ["metadata:read"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :repositories, {:array, :map}
        field :total_count, :integer
        field :permissions, :map
      end
    end

    action :read_file do
      id "github.file.read"
      resource :file
      verb :read
      data_classification :workspace_content
      label "Read file contents"
      description "Read a GitHub repository file by path and optional ref."
      handler Jido.Connect.GitHub.Handlers.Actions.ReadFile
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :path, :string, required?: true, example: "README.md"
        field :ref, :string
      end

      output do
        field :repo, :string
        field :path, :string
        field :name, :string
        field :sha, :string
        field :size, :integer
        field :type, :string
        field :encoding, :string
        field :binary, :boolean
        field :content, :string
        field :content_base64, :string
        field :url, :string
        field :html_url, :string
        field :download_url, :string
      end
    end

    action :update_file do
      id "github.file.update"
      resource :file
      verb :update
      data_classification :workspace_content
      label "Create or update file contents"
      description "Create or update a GitHub repository file by path."
      handler Jido.Connect.GitHub.Handlers.Actions.UpdateFile
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :path, :string, required?: true, example: "README.md"
        field :content, :string, required?: true
        field :message, :string, required?: true
        field :branch, :string
        field :sha, :string
        field :committer, :map
      end

      output do
        field :repo, :string
        field :path, :string
        field :sha, :string
        field :url, :string
        field :html_url, :string
        field :download_url, :string
        field :commit_sha, :string
        field :commit_message, :string
      end
    end
  end
end
