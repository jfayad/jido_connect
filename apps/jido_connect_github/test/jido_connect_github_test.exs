defmodule Jido.Connect.GitHubTest do
  use ExUnit.Case
  alias Jido.Connect

  defmodule FakeGitHubClient do
    def list_issues("org/repo", "open", "token") do
      {:ok, [%{number: 1, url: "https://github.test/1", title: "First", state: "open"}]}
    end

    def create_issue("org/repo", %{title: "Bug", body: nil, labels: []}, "token") do
      {:ok, %{number: 2, url: "https://github.test/2", title: "Bug", state: "open"}}
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
    assert Jido.Connect.GitHub.jido_action_modules() == [
             Jido.Connect.GitHub.Actions.ListIssues,
             Jido.Connect.GitHub.Actions.CreateIssue
           ]

    assert Jido.Connect.GitHub.jido_sensor_modules() == [
             Jido.Connect.GitHub.Sensors.NewIssues
           ]

    assert Jido.Connect.GitHub.jido_plugin_module() == Jido.Connect.GitHub.Plugin

    assert {:module, Jido.Connect.GitHub.Actions.ListIssues} =
             Code.ensure_loaded(Jido.Connect.GitHub.Actions.ListIssues)

    assert {:module, Jido.Connect.GitHub.Sensors.NewIssues} =
             Code.ensure_loaded(Jido.Connect.GitHub.Sensors.NewIssues)

    assert {:module, Jido.Connect.GitHub.Plugin} =
             Code.ensure_loaded(Jido.Connect.GitHub.Plugin)

    assert function_exported?(Jido.Connect.GitHub.Actions.ListIssues, :run, 2)
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

  test "generated action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Jido.Connect.GitHub.Actions.ListIssues.run(%{repo: "org/repo"}, %{
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
             Jido.Connect.GitHub.Actions.ListIssues,
             Jido.Connect.GitHub.Actions.CreateIssue
           ]

    filtered =
      Jido.Connect.GitHub.Plugin.plugin_spec(%{
        allowed_actions: ["github.issue.list"]
      })

    assert filtered.actions == [Jido.Connect.GitHub.Actions.ListIssues]
  end

  test "generated plugin reports basic tool availability" do
    [list_available | _] =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection: elem(context_and_lease(), 0).connection
      })

    assert list_available.state == :available

    [missing_scopes | _] =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection: %{elem(context_and_lease(), 0).connection | scopes: []}
      })

    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["repo"]

    [installation_missing_scopes | _] =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        connection:
          elem(
            context_and_lease(profile: :installation, scopes: ["metadata:read"]),
            0
          ).connection
      })

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

  defp default_scopes(:installation), do: ["metadata:read", "issues:read", "issues:write"]
  defp default_scopes(_profile), do: ["repo"]

  defp owner_type(:installation), do: :installation
  defp owner_type(_profile), do: :user
end
