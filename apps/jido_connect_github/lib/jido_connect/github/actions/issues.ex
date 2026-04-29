defmodule Jido.Connect.GitHub.Actions.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_issues do
      id "github.issue.list"
      resource :issue
      verb :list
      data_classification :workspace_content
      label "List issues"
      description "List issues in a GitHub repository."
      handler Jido.Connect.GitHub.Handlers.Actions.ListIssues
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :state, :string, enum: ["open", "closed", "all"], default: "open"
      end

      output do
        field :issues, {:array, :map}
      end
    end

    action :create_issue do
      id "github.issue.create"
      resource :issue
      verb :create
      data_classification :workspace_content
      label "Create issue"
      description "Create a GitHub issue."
      handler Jido.Connect.GitHub.Handlers.Actions.CreateIssue
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :title, :string, required?: true
        field :body, :string
        field :labels, {:array, :string}, default: []
      end

      output do
        field :number, :integer
        field :url, :string
        field :title, :string
        field :state, :string
      end
    end

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

    action :create_issue_comment do
      id "github.issue_comment.create"
      resource :comment
      verb :create
      data_classification :message_content
      label "Create issue comment"
      description "Create a comment on a GitHub issue or pull request."
      handler Jido.Connect.GitHub.Handlers.Actions.CreateIssueComment
      effect :external_write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :issue_number, :integer, required?: true
        field :body, :string, required?: true
      end

      output do
        field :id, :integer
        field :url, :string
        field :body, :string
      end
    end
  end
end
