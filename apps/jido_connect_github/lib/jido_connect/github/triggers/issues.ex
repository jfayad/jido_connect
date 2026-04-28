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
  end
end
