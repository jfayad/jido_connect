defmodule Jido.Connect.GitHub.Triggers.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
    poll :new_issues do
      id "github.issue.new"
      resource :issue
      verb :watch
      data_classification :workspace_content
      label "New issues"
      description "Poll for new GitHub issues."
      interval_ms 300_000
      checkpoint :updated_at
      dedupe %{key: [:repo, :issue_number]}
      handler Jido.Connect.GitHub.Handlers.Triggers.NewIssuesPoller

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      config do
        field :repo, :string, required?: true, example: "org/repo"
      end

      signal do
        field :repo, :string
        field :issue_number, :integer
        field :title, :string
        field :url, :string
      end
    end

    poll :updated_pull_requests do
      id "github.pull_request.updated"
      resource :pull_request
      verb :watch
      data_classification :workspace_content
      label "Updated pull requests"
      description "Poll for updated GitHub pull requests."
      interval_ms 300_000
      checkpoint :updated_at
      dedupe %{key: [:repo, :pull_number, :updated_at]}
      handler Jido.Connect.GitHub.Handlers.Triggers.UpdatedPullRequestsPoller

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      config do
        field :repo, :string, required?: true, example: "org/repo"
      end

      signal do
        field :repo, :string
        field :pull_number, :integer
        field :title, :string
        field :state, :string
        field :url, :string
        field :updated_at, :string
      end
    end

    poll :workflow_run_updates do
      id "github.workflow_run.updated"
      resource :workflow_run
      verb :watch
      data_classification :workspace_content
      label "Workflow run updates"
      description "Poll for updated or completed GitHub Actions workflow runs."
      interval_ms 300_000
      checkpoint :updated_at
      dedupe %{key: [:repo, :workflow_run_id, :updated_at]}
      handler Jido.Connect.GitHub.Handlers.Triggers.WorkflowRunUpdatesPoller

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      config do
        field :repo, :string, required?: true, example: "org/repo"
        field :workflow, :string
        field :branch, :string
        field :status, :string
        field :event, :string
        field :per_page, :integer, default: 30
      end

      signal do
        field :repo, :string
        field :workflow_run_id, :integer
        field :workflow_run_number, :integer
        field :workflow_name, :string
        field :action, :string
        field :status, :string
        field :conclusion, :string
        field :ci_status, :string
        field :failure, :boolean
        field :branch, :string
        field :sha, :string
        field :workflow_id, :integer
        field :url, :string
        field :created_at, :string
        field :updated_at, :string
        field :workflow_run, :map
      end
    end
  end
end
