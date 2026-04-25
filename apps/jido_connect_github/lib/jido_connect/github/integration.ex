defmodule Jido.Connect.GitHub do
  @moduledoc """
  GitHub integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into:

  - `Jido.Connect.GitHub.Actions.ListIssues`
  - `Jido.Connect.GitHub.Actions.CreateIssue`
  - `Jido.Connect.GitHub.Sensors.NewIssues`
  - `Jido.Connect.GitHub.Plugin`
  """

  use Jido.Connect

  integration do
    id(:github)
    name("GitHub")
    category(:developer_tools)
    docs(["https://docs.github.com/rest"])
    metadata(%{package: :jido_connect_github})
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("GitHub OAuth user")
      authorize_url("https://github.com/login/oauth/authorize")
      token_url("https://github.com/login/oauth/access_token")
      callback_path("/integrations/github/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      scopes(["repo", "read:user"])
      default_scopes(["read:user"])
      pkce?(false)
      refresh?(false)
      revoke?(true)
    end
  end

  actions do
    action :list_issues do
      id("github.issue.list")
      label("List issues")
      description("List issues in a GitHub repository.")
      auth(:user)
      scopes(["repo"])
      mutation?(false)
      risk(:read)
      handler(Jido.Connect.GitHub.Handlers.Actions.ListIssues)

      input do
        field(:repo, :string, required?: true, example: "org/repo")
        field(:state, :string, enum: ["open", "closed", "all"], default: "open")
      end

      output do
        field(:issues, {:array, :map})
      end
    end

    action :create_issue do
      id("github.issue.create")
      label("Create issue")
      description("Create a GitHub issue.")
      auth(:user)
      scopes(["repo"])
      mutation?(true)
      risk(:write)
      confirmation(:required_for_ai)
      handler(Jido.Connect.GitHub.Handlers.Actions.CreateIssue)

      input do
        field(:repo, :string, required?: true, example: "org/repo")
        field(:title, :string, required?: true)
        field(:body, :string)
        field(:labels, {:array, :string}, default: [])
      end

      output do
        field(:number, :integer)
        field(:url, :string)
        field(:title, :string)
        field(:state, :string)
      end
    end
  end

  triggers do
    poll :new_issues do
      id("github.issue.new")
      label("New issues")
      description("Poll for new GitHub issues.")
      auth(:user)
      scopes(["repo"])
      interval_ms(300_000)
      checkpoint(:updated_at)
      dedupe(%{key: [:repo, :issue_number]})
      handler(Jido.Connect.GitHub.Handlers.Triggers.NewIssuesPoller)

      config do
        field(:repo, :string, required?: true, example: "org/repo")
      end

      signal do
        field(:repo, :string)
        field(:issue_number, :integer)
        field(:title, :string)
        field(:url, :string)
      end
    end
  end
end
