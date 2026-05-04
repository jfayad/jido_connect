defmodule Jido.Connect.GitHub.Actions.Search do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :search_issues do
      id "github.issue.search"
      resource :issue
      verb :search
      data_classification :workspace_content
      label "Search issues and pull requests"
      description "Search GitHub issues and pull requests with query helpers and pagination."
      handler Jido.Connect.GitHub.Handlers.Actions.SearchIssues
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :query, :string, default: ""
        field :type, :string, enum: ["issue", "pull_request", "all"], default: "all"
        field :state, :string, enum: ["open", "closed", "all"], default: "open"
        field :author, :string
        field :assignee, :string
        field :label, :string

        field :sort, :string,
          enum: ["comments", "reactions", "created", "updated"],
          default: "updated"

        field :direction, :string, enum: ["asc", "desc"], default: "desc"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :results, {:array, :map}
        field :total_count, :integer
      end
    end
  end
end
