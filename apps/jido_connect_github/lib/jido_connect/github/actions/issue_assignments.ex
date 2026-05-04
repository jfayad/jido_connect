defmodule Jido.Connect.GitHub.Actions.IssueAssignments do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :assign_issue do
      id "github.issue.assign"
      resource :issue
      verb :update
      data_classification :workspace_content
      label "Assign issue"
      description "Assign users to an existing GitHub issue."
      handler Jido.Connect.GitHub.Handlers.Actions.AssignIssue
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :issue_number, :integer, required?: true
        field :assignees, {:array, :string}, required?: true
      end

      output do
        field :number, :integer
        field :url, :string
        field :title, :string
        field :state, :string
        field :assignees, {:array, :map}
      end
    end
  end
end
