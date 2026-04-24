defmodule Jido.Connect.Demo.Integrations do
  @moduledoc false

  @integrations [
    %{
      id: "github",
      name: "GitHub",
      package: "jido_connect_github",
      status: :available,
      auth_modes: ["GitHub App", "OAuth App", "Manual token"],
      description:
        "Issues actions, GitHub App setup, OAuth callback capture, and webhook intake.",
      paths: %{
        setup: "/integrations/github/setup",
        setup_complete: "/integrations/github/setup/complete",
        oauth_start: "/integrations/github/oauth/start",
        oauth_callback: "/integrations/github/oauth/callback",
        webhook: "/integrations/github/webhook"
      },
      checks: [
        %{label: "App setup callback", method: "GET", path: "/integrations/github/setup"},
        %{
          label: "Manifest conversion callback",
          method: "GET",
          path: "/integrations/github/setup/complete"
        },
        %{
          label: "OAuth authorization start",
          method: "GET",
          path: "/integrations/github/oauth/start"
        },
        %{label: "OAuth callback", method: "GET", path: "/integrations/github/oauth/callback"},
        %{label: "Webhook receiver", method: "POST", path: "/integrations/github/webhook"}
      ]
    },
    %{
      id: "slack",
      name: "Slack",
      package: "jido_connect_slack",
      status: :planned,
      auth_modes: ["OAuth 2.0"],
      description:
        "Placeholder for future install callbacks, event subscriptions, and slash commands.",
      paths: %{},
      checks: []
    },
    %{
      id: "google",
      name: "Google Workspace",
      package: "jido_connect_google",
      status: :planned,
      auth_modes: ["OAuth 2.0"],
      description:
        "Placeholder for future OAuth consent, token refresh, and webhook renewal flows.",
      paths: %{},
      checks: []
    }
  ]

  def all, do: @integrations

  def api_index do
    Enum.map(@integrations, fn integration ->
      %{
        id: integration.id,
        name: integration.name,
        package: integration.package,
        status: integration.status,
        auth_modes: integration.auth_modes,
        description: integration.description,
        paths: integration.paths
      }
    end)
  end
end
