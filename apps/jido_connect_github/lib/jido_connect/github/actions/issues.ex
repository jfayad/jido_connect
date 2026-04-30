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

    action :add_issue_labels do
      id "github.issue.label.add"
      resource :issue
      verb :update
      data_classification :workspace_content
      label "Add labels to issue"
      description "Add labels to an existing GitHub issue."
      handler Jido.Connect.GitHub.Handlers.Actions.AddIssueLabels
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :issue_number, :integer, required?: true
        field :labels, {:array, :string}, required?: true
      end

      output do
        field :labels, {:array, :map}
      end
    end

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

    action :list_workflow_runs do
      id "github.workflow_run.list"
      resource :workflow_run
      verb :list
      data_classification :workspace_metadata
      label "List workflow runs"
      description "List GitHub Actions workflow runs in a repository."
      handler Jido.Connect.GitHub.Handlers.Actions.ListWorkflowRuns
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :workflow, :string
        field :branch, :string
        field :status, :string
        field :event, :string
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :workflow_runs, {:array, :map}
        field :total_count, :integer
      end
    end

    action :dispatch_workflow do
      id "github.workflow.dispatch"
      resource :workflow
      verb :dispatch
      data_classification :workspace_metadata
      label "Dispatch workflow"
      description "Dispatch a GitHub Actions workflow for a specific ref with typed inputs."
      handler Jido.Connect.GitHub.Handlers.Actions.DispatchWorkflow
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :workflow, :string, required?: true, example: "ci.yml"
        field :ref, :string, required?: true, example: "main"
        field :inputs, :map, default: %{}
      end

      output do
        field :dispatched, :boolean
        field :repo, :string
        field :workflow, :string
        field :ref, :string
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

    action :list_pull_request_files do
      id "github.pull_request_file.list"
      resource :pull_request_file
      verb :list
      data_classification :workspace_content
      label "List pull request files"
      description "List changed files on a GitHub pull request with per-file change stats."
      handler Jido.Connect.GitHub.Handlers.Actions.ListPullRequestFiles
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :pull_number, :integer, required?: true
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :files, {:array, :map}
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

    action :request_pull_request_reviewers do
      id "github.pull_request.reviewers.request"
      resource :pull_request
      verb :update
      data_classification :workspace_content
      label "Request pull request reviewers"
      description "Request users or teams to review a GitHub pull request."
      handler Jido.Connect.GitHub.Handlers.Actions.RequestPullRequestReviewers
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :pull_number, :integer, required?: true
        field :reviewers, {:array, :string}, default: []
        field :team_reviewers, {:array, :string}, default: []
      end

      output do
        field :number, :integer
        field :url, :string
        field :title, :string
        field :state, :string
        field :requested_reviewers, {:array, :map}
        field :requested_teams, {:array, :map}
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

    action :list_issue_comments do
      id "github.issue_comment.list"
      resource :comment
      verb :list
      data_classification :message_content
      label "List issue comments"
      description "List comments on a GitHub issue or pull request."
      handler Jido.Connect.GitHub.Handlers.Actions.ListIssueComments
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :issue_number, :integer, required?: true
        field :since, :string
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :comments, {:array, :map}
      end
    end
  end
end
