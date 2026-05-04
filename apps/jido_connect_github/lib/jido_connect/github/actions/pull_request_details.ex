defmodule Jido.Connect.GitHub.Actions.PullRequestDetails do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
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
  end
end
