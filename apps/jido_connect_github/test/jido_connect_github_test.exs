defmodule Jido.Connect.GitHubTest do
  use ExUnit.Case
  alias Jido.Connect

  defmodule FakeGitHubClient do
    def list_repositories(%{page: 2, per_page: 10}, "token") do
      {:ok,
       %{
         total_count: 1,
         repositories: [
           %{
             id: 10,
             name: "repo",
             full_name: "org/repo",
             owner: %{login: "org", type: "Organization"},
             private: true,
             default_branch: "main",
             url: "https://github.test/org/repo"
           }
         ]
       }}
    end

    def list_issues("org/repo", "open", "token") do
      {:ok, [%{number: 1, url: "https://github.test/1", title: "First", state: "open"}]}
    end

    def list_pull_requests(
          %{
            repo: "org/repo",
            state: "open",
            head: "octo:feature",
            base: "main",
            sort: "updated",
            direction: "asc",
            page: 2,
            per_page: 10
          },
          "token"
        ) do
      {:ok,
       [
         %{
           number: 4,
           url: "https://github.test/pull/4",
           title: "Feature",
           state: "open",
           head: %{ref: "feature"},
           base: %{ref: "main"}
         }
       ]}
    end

    def get_pull_request("org/repo", 4, "token") do
      {:ok,
       %{
         number: 4,
         url: "https://github.test/pull/4",
         title: "Feature",
         state: "open",
         draft: false,
         merged: false,
         mergeable: true,
         mergeable_state: "clean",
         head: %{ref: "feature"},
         base: %{ref: "main"},
         issue: %{
           number: 4,
           title: "Feature",
           state: "open",
           labels: [%{name: "enhancement"}],
           assignees: [%{login: "octocat"}],
           milestone: %{title: "v1"}
         }
       }}
    end

    def create_issue("org/repo", %{title: "Bug", body: nil, labels: []}, "token") do
      {:ok, %{number: 2, url: "https://github.test/2", title: "Bug", state: "open"}}
    end

    def create_pull_request(
          "org/repo",
          %{
            title: "Feature",
            body: "Implements the feature",
            head: "octo:feature",
            base: "main",
            draft: true,
            maintainer_can_modify: false
          },
          "token"
        ) do
      {:ok,
       %{
         number: 5,
         url: "https://github.test/pull/5",
         title: "Feature",
         state: "open",
         draft: true,
         maintainer_can_modify: false,
         head: %{ref: "feature"},
         base: %{ref: "main"}
       }}
    end

    def update_pull_request(
          "org/repo",
          5,
          %{
            title: "Updated feature",
            body: "Updated body",
            base: "release",
            state: "open",
            maintainer_can_modify: true,
            draft: false
          },
          "token"
        ) do
      {:ok,
       %{
         number: 5,
         url: "https://github.test/pull/5",
         title: "Updated feature",
         state: "open",
         draft: false,
         maintainer_can_modify: true,
         head: %{ref: "feature"},
         base: %{ref: "release"}
       }}
    end

    def update_issue("org/repo", 2, %{title: "Bug", labels: ["bug"], type: "Bug"}, "token") do
      {:ok, %{number: 2, url: "https://github.test/2", title: "Bug", state: "open"}}
    end

    def create_issue_comment("org/repo", 2, "Ship it", "token") do
      {:ok, %{id: 3, url: "https://github.test/comments/3", body: "Ship it"}}
    end

    def list_new_issues("org/repo", nil, "token") do
      {:ok,
       [
         %{
           number: 3,
           url: "https://github.test/3",
           title: "Third",
           updated_at: "2026-04-24T20:00:00Z"
         }
       ]}
    end
  end

  test "GitHub integration declares first actions and poll trigger" do
    spec = Jido.Connect.GitHub.integration()

    assert spec.id == :github
    assert spec.package == :jido_connect_github
    assert spec.status == :available
    assert :issues in spec.tags
    assert [%{id: :repo_access, decision: :allow_operation}] = spec.policies
    assert {:user, :oauth2} in Enum.map(spec.auth_profiles, &{&1.id, &1.kind})
    assert {:installation, :app_installation} in Enum.map(spec.auth_profiles, &{&1.id, &1.kind})

    assert Enum.find(spec.auth_profiles, &(&1.id == :installation)).setup ==
             :github_app_installation

    assert {:ok,
            %{
              id: "github.repo.list",
              resource: :repository,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.repo.list")

    assert {:ok,
            %{
              id: "github.issue.list",
              resource: :issue,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.issue.list")

    assert {:ok, %{id: "github.issue.create", mutation?: true, confirmation: :required_for_ai}} =
             Connect.action(spec, "github.issue.create")

    assert {:ok,
            %{
              id: "github.pull_request.list",
              resource: :pull_request,
              verb: :list,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.pull_request.list")

    assert {:ok,
            %{
              id: "github.pull_request.get",
              resource: :pull_request,
              verb: :get,
              mutation?: false,
              auth_profiles: [:user, :installation],
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.action(spec, "github.pull_request.get")

    assert {:ok,
            %{
              id: "github.pull_request.create",
              resource: :pull_request,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.pull_request.create")

    assert {:ok,
            %{
              id: "github.pull_request.update",
              resource: :pull_request,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.pull_request.update")

    assert {:ok,
            %{
              id: "github.issue.update",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              policies: [:repo_access],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue.update")

    assert {:ok,
            %{
              id: "github.issue_comment.create",
              resource: :comment,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} = Connect.action(spec, "github.issue_comment.create")

    assert {:ok,
            %{
              id: "github.issue.new",
              kind: :poll,
              checkpoint: :updated_at,
              auth_profiles: [:user, :installation],
              scope_resolver: Jido.Connect.GitHub.ScopeResolver
            }} =
             Connect.trigger(spec, "github.issue.new")
  end

  test "GitHub catalog entry exposes setup, auth, and runtime capabilities" do
    entry = Connect.Catalog.entry(Jido.Connect.GitHub)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_github
    assert entry.tags == [:source_control, :issues, :developer_tools]
    assert [%{id: :repo_access}] = entry.policies
    assert MapSet.subset?(MapSet.new([:oauth2, :app_installation]), features)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :polling)
    assert MapSet.member?(features, :github_app_manifest)
    assert MapSet.member?(features, :webhook_verification)
  end

  test "GitHub integration compiles Jido action, sensor, and plugin modules" do
    assert Application.get_env(:jido_connect_github, :jido_connect_providers) == [
             Jido.Connect.GitHub
           ]

    assert Jido.Connect.GitHub.jido_action_modules() == [
             Jido.Connect.GitHub.Actions.ListRepositories,
             Jido.Connect.GitHub.Actions.ListIssues,
             Jido.Connect.GitHub.Actions.CreateIssue,
             Jido.Connect.GitHub.Actions.ListPullRequests,
             Jido.Connect.GitHub.Actions.GetPullRequest,
             Jido.Connect.GitHub.Actions.CreatePullRequest,
             Jido.Connect.GitHub.Actions.UpdatePullRequest,
             Jido.Connect.GitHub.Actions.UpdateIssue,
             Jido.Connect.GitHub.Actions.CreateIssueComment
           ]

    assert Jido.Connect.GitHub.jido_sensor_modules() == [
             Jido.Connect.GitHub.Sensors.NewIssues
           ]

    assert Jido.Connect.GitHub.jido_plugin_module() == Jido.Connect.GitHub.Plugin

    assert %Connect.Catalog.Manifest{
             id: :github,
             package: :jido_connect_github,
             generated_modules: %{
               actions: [
                 Jido.Connect.GitHub.Actions.ListRepositories,
                 Jido.Connect.GitHub.Actions.ListIssues,
                 Jido.Connect.GitHub.Actions.CreateIssue,
                 Jido.Connect.GitHub.Actions.ListPullRequests,
                 Jido.Connect.GitHub.Actions.GetPullRequest,
                 Jido.Connect.GitHub.Actions.CreatePullRequest,
                 Jido.Connect.GitHub.Actions.UpdatePullRequest,
                 Jido.Connect.GitHub.Actions.UpdateIssue,
                 Jido.Connect.GitHub.Actions.CreateIssueComment
               ],
               sensors: [Jido.Connect.GitHub.Sensors.NewIssues],
               plugin: Jido.Connect.GitHub.Plugin
             }
           } = Jido.Connect.GitHub.jido_connect_manifest()

    assert {:module, Jido.Connect.GitHub.Actions.ListIssues} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListIssues)

    assert {:module, Jido.Connect.GitHub.Actions.ListRepositories} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListRepositories)

    assert {:module, Jido.Connect.GitHub.Actions.CreateIssueComment} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.CreateIssueComment)

    assert {:module, Jido.Connect.GitHub.Actions.ListPullRequests} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListPullRequests)

    assert {:module, Jido.Connect.GitHub.Actions.GetPullRequest} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.GetPullRequest)

    assert {:module, Jido.Connect.GitHub.Actions.CreatePullRequest} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.CreatePullRequest)

    assert {:module, Jido.Connect.GitHub.Actions.UpdatePullRequest} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.UpdatePullRequest)

    assert {:module, Jido.Connect.GitHub.Actions.UpdateIssue} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.UpdateIssue)

    assert {:module, Jido.Connect.GitHub.Sensors.NewIssues} =
             Code.ensure_loaded(Jido.Connect.GitHub.Sensors.NewIssues)

    assert {:module, Jido.Connect.GitHub.Plugin} =
             Code.ensure_loaded(Jido.Connect.GitHub.Plugin)

    assert function_exported?(Jido.Connect.GitHub.Actions.ListIssues, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListRepositories, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.ListPullRequests, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.GetPullRequest, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.CreatePullRequest, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.UpdatePullRequest, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.UpdateIssue, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Actions.CreateIssueComment, :run, 2)
    assert function_exported?(Jido.Connect.GitHub.Sensors.NewIssues, :init, 2)
    assert function_exported?(Jido.Connect.GitHub.Plugin, :plugin_spec, 1)
  end

  test "generated action metadata tracks the DSL action" do
    projection = Jido.Connect.GitHub.Actions.CreateIssue.jido_connect_projection()

    assert projection.action_id == "github.issue.create"
    assert projection.label == "Create issue"
    assert Enum.map(projection.input, & &1.name) == [:repo, :title, :body, :labels]
    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :issue
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreateIssue.name() == "github_issue_create"

    assert Jido.Connect.GitHub.Actions.CreateIssue.description() ==
             "Create a GitHub issue."
  end

  test "generated issue comment action metadata tracks high-risk DSL fields" do
    projection = Jido.Connect.GitHub.Actions.CreateIssueComment.jido_connect_projection()

    assert projection.action_id == "github.issue_comment.create"
    assert projection.label == "Create issue comment"
    assert Enum.map(projection.input, & &1.name) == [:repo, :issue_number, :body]
    assert Enum.map(projection.output, & &1.name) == [:id, :url, :body]
    assert projection.data_classification == :message_content
    assert projection.risk == :external_write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :comment
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreateIssueComment.name() == "github_issue_comment_create"
  end

  test "generated update issue action metadata tracks editable fields" do
    projection = Jido.Connect.GitHub.Actions.UpdateIssue.jido_connect_projection()

    assert projection.action_id == "github.issue.update"
    assert projection.label == "Update issue"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :issue_number,
             :title,
             :body,
             :state,
             :labels,
             :milestone,
             :assignees,
             :type
           ]

    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :issue
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.UpdateIssue.name() == "github_issue_update"
  end

  test "generated pull request list action metadata tracks filter fields" do
    projection = Jido.Connect.GitHub.Actions.ListPullRequests.jido_connect_projection()

    assert projection.action_id == "github.pull_request.list"
    assert projection.label == "List pull requests"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :state,
             :head,
             :base,
             :sort,
             :direction,
             :page,
             :per_page
           ]

    assert Enum.map(projection.output, & &1.name) == [:pull_requests]
    assert projection.risk == :read
    assert projection.resource == :pull_request
    assert projection.verb == :list
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.ListPullRequests.name() == "github_pull_request_list"
  end

  test "generated get pull request action metadata tracks detail fields" do
    projection = Jido.Connect.GitHub.Actions.GetPullRequest.jido_connect_projection()

    assert projection.action_id == "github.pull_request.get"
    assert projection.label == "Get pull request"
    assert Enum.map(projection.input, & &1.name) == [:repo, :pull_number]
    assert Enum.map(projection.output, & &1.name) == [:pull_request]
    assert projection.risk == :read
    assert projection.resource == :pull_request
    assert projection.verb == :get
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.GetPullRequest.name() == "github_pull_request_get"
  end

  test "generated create pull request action metadata tracks creation fields" do
    projection = Jido.Connect.GitHub.Actions.CreatePullRequest.jido_connect_projection()

    assert projection.action_id == "github.pull_request.create"
    assert projection.label == "Create pull request"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :title,
             :body,
             :head,
             :base,
             :draft,
             :maintainer_can_modify,
             :risk,
             :confirmation
           ]

    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :pull_request
    assert projection.verb == :create
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.CreatePullRequest.name() == "github_pull_request_create"
  end

  test "generated update pull request action metadata tracks editable fields" do
    projection = Jido.Connect.GitHub.Actions.UpdatePullRequest.jido_connect_projection()

    assert projection.action_id == "github.pull_request.update"
    assert projection.label == "Update pull request"

    assert Enum.map(projection.input, & &1.name) == [
             :repo,
             :pull_number,
             :title,
             :body,
             :base,
             :state,
             :maintainer_can_modify,
             :draft
           ]

    assert Enum.map(projection.output, & &1.name) == [:number, :url, :title, :state]
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert projection.resource == :pull_request
    assert projection.verb == :update
    assert projection.policies == [:repo_access]
    assert projection.auth_profiles == [:user, :installation]
    assert projection.scope_resolver == Jido.Connect.GitHub.ScopeResolver
    assert Jido.Connect.GitHub.Actions.UpdatePullRequest.name() == "github_pull_request_update"
  end

  test "invokes GitHub list issue action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.list",
               %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub list repositories action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 1,
              repositories: [%{id: 10, full_name: "org/repo", owner: %{login: "org"}}]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.repo.list",
               %{page: 2, per_page: 10},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub update issue action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 2, title: "Bug", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.update",
               %{repo: "org/repo", issue_number: 2, title: "Bug", labels: ["bug"], type: "Bug"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub list pull requests action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              pull_requests: [
                %{number: 4, title: "Feature", head: %{ref: "feature"}, base: %{ref: "main"}}
              ]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.list",
               %{
                 repo: "org/repo",
                 state: "open",
                 head: "octo:feature",
                 base: "main",
                 sort: "updated",
                 direction: "asc",
                 page: 2,
                 per_page: 10
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub get pull request action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              pull_request: %{
                number: 4,
                title: "Feature",
                mergeable: true,
                mergeable_state: "clean",
                head: %{ref: "feature"},
                base: %{ref: "main"},
                issue: %{
                  labels: [%{name: "enhancement"}],
                  assignees: [%{login: "octocat"}],
                  milestone: %{title: "v1"}
                }
              }
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.get",
               %{repo: "org/repo", pull_number: 4},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub create pull request action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 5, title: "Feature", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.create",
               %{
                 repo: "org/repo",
                 title: "Feature",
                 body: "Implements the feature",
                 head: "octo:feature",
                 base: "main",
                 draft: true,
                 maintainer_can_modify: false,
                 risk: "low",
                 confirmation: "approved"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub update pull request action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 5, title: "Updated feature", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.update",
               %{
                 repo: "org/repo",
                 pull_number: 5,
                 title: "Updated feature",
                 body: "Updated body",
                 base: "release",
                 state: "open",
                 maintainer_can_modify: true,
                 draft: false
               },
               context: context,
               credential_lease: lease
             )
  end

  test "GitHub App installation connections use installation-specific scopes" do
    {context, lease} =
      context_and_lease(profile: :installation, scopes: ["metadata:read", "issues:read"])

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.list",
               %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    missing_write = %{context | connection: %{context.connection | scopes: ["metadata:read"]}}

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["issues:write"]}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.create",
               %{repo: "org/repo", title: "Bug"},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["pull_requests:write"]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.create",
               %{repo: "org/repo", title: "Feature", head: "octo:feature", base: "main"},
               context: missing_write,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["pull_requests:write"]
            }} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.pull_request.update",
               %{repo: "org/repo", pull_number: 5, title: "Updated feature"},
               context: missing_write,
               credential_lease: lease
             )
  end

  test "invokes GitHub create issue action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{number: 2, title: "Bug", state: "open"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue.create",
               %{repo: "org/repo", title: "Bug"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes GitHub create issue comment action through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{id: 3, body: "Ship it"}} =
             Connect.invoke(
               Jido.Connect.GitHub.integration(),
               "github.issue_comment.create",
               %{repo: "org/repo", issue_number: 2, body: "Ship it"},
               context: context,
               credential_lease: lease
             )
  end

  test "generated action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Jido.Connect.GitHub.Actions.ListIssues.run(%{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })
  end

  test "generated repository action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              total_count: 1,
              repositories: [%{id: 10, full_name: "org/repo", owner: %{login: "org"}}]
            }} =
             Jido.Connect.GitHub.Actions.ListRepositories.run(%{page: 2, per_page: 10}, %{
               integration_context: context,
               credential_lease: lease
             })
  end

  test "generated action rejects missing runtime context before provider execution" do
    assert {:error, %Connect.Error.AuthError{reason: :context_required}} =
             Jido.Connect.GitHub.Actions.ListIssues.run(%{repo: "org/repo"}, %{})
  end

  test "generated poll sensor initializes and emits Jido signals on tick" do
    {context, lease} = context_and_lease()

    assert {:ok, state, [{:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.NewIssues.init(%{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, _state, [{:emit, signal}, {:schedule, 300_000}]} =
             Jido.Connect.GitHub.Sensors.NewIssues.handle_event(:tick, state)

    assert %Jido.Signal{} = signal
    assert signal.type == "github.issue.new"
    assert signal.source == "/jido/connect/github"
    assert signal.data.issue_number == 3
  end

  test "generated plugin lists and filters generated actions" do
    spec = Jido.Connect.GitHub.Plugin.plugin_spec(%{})

    assert spec.actions == [
             Jido.Connect.GitHub.Actions.ListRepositories,
             Jido.Connect.GitHub.Actions.ListIssues,
             Jido.Connect.GitHub.Actions.CreateIssue,
             Jido.Connect.GitHub.Actions.ListPullRequests,
             Jido.Connect.GitHub.Actions.GetPullRequest,
             Jido.Connect.GitHub.Actions.CreatePullRequest,
             Jido.Connect.GitHub.Actions.UpdatePullRequest,
             Jido.Connect.GitHub.Actions.UpdateIssue,
             Jido.Connect.GitHub.Actions.CreateIssueComment
           ]

    filtered =
      Jido.Connect.GitHub.Plugin.plugin_spec(%{
        allowed_actions: ["github.issue.list"]
      })

    assert filtered.actions == [Jido.Connect.GitHub.Actions.ListIssues]
  end

  test "generated plugin reports basic tool availability" do
    available_tools =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection: elem(context_and_lease(), 0).connection
      })

    list_available = availability_for(available_tools, "github.repo.list")
    assert list_available.state == :available

    missing_scope_tools =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection: %{elem(context_and_lease(), 0).connection | scopes: []}
      })

    missing_scopes = availability_for(missing_scope_tools, "github.issue.list")
    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["repo"]

    installation_tools =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection:
          elem(
            context_and_lease(profile: :installation, scopes: ["metadata:read"]),
            0
          ).connection
      })

    installation_missing_scopes = availability_for(installation_tools, "github.issue.list")
    assert installation_missing_scopes.state == :missing_scopes
    assert installation_missing_scopes.missing_scopes == ["issues:read"]

    [disabled | _] =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        allowed_actions: []
      })

    assert disabled.state == :disabled_by_policy

    [required | _] = Jido.Connect.GitHub.Plugin.tool_availability(%{})
    assert required.state == :connection_required
  end

  test "validates required action input fields" do
    assert {:error, %Connect.Error.ValidationError{reason: :input, details: details}} =
             Connect.invoke(Jido.Connect.GitHub.integration(), "github.issue.list", %{},
               context: %{tenant_id: "tenant_1", actor: %{id: "user_1", type: :user}},
               credential_lease: %{
                 connection_id: "conn_1",
                 expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
                 fields: %{github_client: FakeGitHubClient}
               }
             )

    assert [%Zoi.Error{code: :required, path: [:repo]}] = details.errors
  end

  defp context_and_lease(opts \\ []) do
    profile = Keyword.get(opts, :profile, :user)
    scopes = Keyword.get(opts, :scopes, default_scopes(profile))

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :github,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: owner_type(profile),
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", github_client: FakeGitHubClient}
      })

    {context, lease}
  end

  defp default_scopes(:installation),
    do: ["metadata:read", "issues:read", "issues:write", "pull_requests:read"]

  defp default_scopes(_profile), do: ["repo"]

  defp owner_type(:installation), do: :installation
  defp owner_type(_profile), do: :user

  defp availability_for(availability, tool) do
    Enum.find(availability, &(&1.tool == tool)) || flunk("missing availability for #{tool}")
  end
end
