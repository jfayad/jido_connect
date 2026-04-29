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
  end
end
