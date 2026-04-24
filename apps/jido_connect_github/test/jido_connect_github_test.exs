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

    assert {:ok, %{id: "github.issue.list", mutation?: false}} =
             Connect.action(spec, "github.issue.list")

    assert {:ok, %{id: "github.issue.create", mutation?: true, confirmation: :required_for_ai}} =
             Connect.action(spec, "github.issue.create")

    assert {:ok, %{id: "github.issue.new", kind: :poll, checkpoint: :updated_at}} =
             Connect.trigger(spec, "github.issue.new")
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
    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
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

  test "generated action delegates to integration invoke runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{issues: [%{number: 1, title: "First"}]}} =
             Jido.Connect.GitHub.Actions.ListIssues.run(%{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })
  end

  test "generated action rejects missing runtime context before provider execution" do
    assert {:error, :context_required} =
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

    [disabled | _] =
      Jido.Connect.GitHub.Plugin.tool_availability(%{
        allowed_actions: []
      })

    assert disabled.state == :disabled_by_policy

    [required | _] = Jido.Connect.GitHub.Plugin.tool_availability(%{})
    assert required.state == :connection_required
  end

  test "validates required action input fields" do
    assert {:error, [%Zoi.Error{code: :required, path: [:repo]}]} =
             Connect.invoke(Jido.Connect.GitHub.integration(), "github.issue.list", %{},
               context: %{tenant_id: "tenant_1", actor: %{id: "user_1", type: :user}},
               credential_lease: %{
                 connection_id: "conn_1",
                 expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
                 fields: %{github_client: FakeGitHubClient}
               }
             )
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :github,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["repo"]
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
end
