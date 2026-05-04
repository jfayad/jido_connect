defmodule Jido.Connect.GitHub.Actions.IssueUpdates do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :update_issue do
      id "github.issue.update"
      resource :issue
      verb :update
      data_classification :workspace_content
      label "Update issue"
      description "Update a GitHub issue."
      handler Jido.Connect.GitHub.Handlers.Actions.UpdateIssue
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :issue_number, :integer, required?: true
        field :title, :string
        field :body, :string
        field :state, :string, enum: ["open", "closed"]
        field :labels, {:array, :string}
        field :milestone, :integer
        field :assignees, {:array, :string}
        field :type, :string
      end

      output do
        field :number, :integer
        field :url, :string
        field :title, :string
        field :state, :string
      end
    end
  end
end
