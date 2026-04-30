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
        field :tarball_url, :string
        field :zipball_url, :string
        field :created_at, :string
        field :published_at, :string
        field :body, :string
      end
    end

    action :list_workflow_run_jobs do
      id "github.workflow_run.job.list"
      resource :workflow_run_job
      verb :list
      data_classification :workspace_metadata
      label "List workflow run jobs"

      description "List GitHub Actions jobs and steps for a workflow run with normalized CI status."

      handler Jido.Connect.GitHub.Handlers.Actions.ListWorkflowRunJobs
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :run_id, :integer, required?: true
        field :filter, :string, enum: ["latest", "all"], default: "latest"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :jobs, {:array, :map}
        field :total_count, :integer
        field :ci_status, :string
      end
    end

    action :rerun_workflow_run do
      id "github.workflow_run.rerun"
      resource :workflow_run
      verb :dispatch
      data_classification :workspace_metadata
      label "Rerun workflow run"

      description "Rerun all jobs or only failed jobs for a GitHub Actions workflow run."

      handler Jido.Connect.GitHub.Handlers.Actions.RerunWorkflowRun
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :run_id, :integer, required?: true
        field :failed_only, :boolean, default: false
      end

      output do
        field :rerun_requested, :boolean
        field :repo, :string
        field :run_id, :integer
        field :failed_only, :boolean
      end
    end

    action :cancel_workflow_run do
      id "github.workflow_run.cancel"
      resource :workflow_run
      verb :cancel
      data_classification :workspace_metadata
      label "Cancel workflow run"
      description "Cancel an in-progress GitHub Actions workflow run."
      handler Jido.Connect.GitHub.Handlers.Actions.CancelWorkflowRun
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :run_id, :integer, required?: true
      end

      output do
        field :cancel_requested, :boolean
        field :repo, :string
        field :run_id, :integer
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

    action :create_pull_request_review_comment do
      id "github.pull_request.review_comment.create"
      resource :pull_request_review_comment
      verb :create
      data_classification :message_content
      label "Create pull request review comment"
      description "Create a review comment on a GitHub pull request diff."
      handler Jido.Connect.GitHub.Handlers.Actions.CreatePullRequestReviewComment
      effect :external_write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :pull_number, :integer, required?: true
        field :body, :string, required?: true
        field :commit_id, :string, required?: true
        field :path, :string, required?: true
        field :position, :integer
        field :line, :integer
        field :side, :string, enum: ["LEFT", "RIGHT"]
        field :start_line, :integer
        field :start_side, :string, enum: ["LEFT", "RIGHT"]
      end

      output do
        field :id, :integer
        field :url, :string
        field :body, :string
        field :path, :string
        field :position, :integer
        field :line, :integer
        field :side, :string
        field :start_line, :integer
        field :start_side, :string
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
