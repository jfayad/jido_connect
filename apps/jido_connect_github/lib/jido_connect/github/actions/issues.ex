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

    action :list_pull_requests do
      id "github.pull_request.list"
      resource :pull_request
      verb :list
      data_classification :workspace_content
      label "List pull requests"
      description "List pull requests in a GitHub repository."
      handler Jido.Connect.GitHub.Handlers.Actions.ListPullRequests
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :state, :string, enum: ["open", "closed", "all"], default: "open"
        field :head, :string
        field :base, :string

        field :sort, :string,
          enum: ["created", "updated", "popularity", "long-running"],
          default: "created"

        field :direction, :string, enum: ["asc", "desc"], default: "desc"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :pull_requests, {:array, :map}
      end
    end

    action :get_pull_request do
      id "github.pull_request.get"
      resource :pull_request
      verb :get
      data_classification :workspace_content
      label "Get pull request"
      description "Fetch pull request details, refs, mergeability metadata, and issue context."
      handler Jido.Connect.GitHub.Handlers.Actions.GetPullRequest
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :pull_number, :integer, required?: true
      end

      output do
        field :pull_request, :map
      end
    end

    action :create_pull_request do
      id "github.pull_request.create"
      resource :pull_request
      verb :create
      data_classification :workspace_content
      label "Create pull request"
      description "Create a GitHub pull request."
      handler Jido.Connect.GitHub.Handlers.Actions.CreatePullRequest
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
        field :head, :string, required?: true
        field :base, :string, required?: true
        field :draft, :boolean, default: false
        field :maintainer_can_modify, :boolean, default: true
        field :risk, :string
        field :confirmation, :string
      end

      output do
        field :number, :integer
        field :url, :string
        field :title, :string
        field :state, :string
      end
    end

    action :update_pull_request do
      id "github.pull_request.update"
      resource :pull_request
      verb :update
      data_classification :workspace_content
      label "Update pull request"
      description "Update a GitHub pull request."
      handler Jido.Connect.GitHub.Handlers.Actions.UpdatePullRequest
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :pull_number, :integer, required?: true
        field :title, :string
        field :body, :string
        field :base, :string
        field :state, :string, enum: ["open", "closed"]
        field :maintainer_can_modify, :boolean
        field :draft, :boolean
      end

      output do
        field :number, :integer
        field :url, :string
        field :title, :string
        field :state, :string
      end
    end

    action :merge_pull_request do
      id "github.pull_request.merge"
      resource :pull_request
      verb :merge
      data_classification :workspace_content
      label "Merge pull request"
      description "Merge a GitHub pull request into the base branch."
      handler Jido.Connect.GitHub.Handlers.Actions.MergePullRequest
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :pull_number, :integer, required?: true
        field :merge_method, :string, required?: true, enum: ["merge", "squash", "rebase"]
        field :commit_title, :string
        field :commit_message, :string
        field :sha, :string
      end

      output do
        field :sha, :string
        field :merged, :boolean
        field :message, :string
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
