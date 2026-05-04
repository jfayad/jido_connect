defmodule Jido.Connect.GitHub.Actions.WorkflowRunControls do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
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
  end
end
