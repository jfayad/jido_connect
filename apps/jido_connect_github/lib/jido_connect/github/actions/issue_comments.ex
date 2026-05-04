defmodule Jido.Connect.GitHub.Actions.IssueComments do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
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
