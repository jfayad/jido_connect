defmodule Jido.Connect.GitHub do
  @moduledoc """
  GitHub integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions, Sensors, and Plugin
  namespaces.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.GitHub.Actions.Repositories,
      Jido.Connect.GitHub.Actions.Issues,
      Jido.Connect.GitHub.Triggers.Issues
    ]

  integration do
    id :github
    name "GitHub"
    description "GitHub repository, issue, app installation, and webhook tools."
    category :developer_tools
    docs ["https://docs.github.com/rest"]
  end

  catalog do
    package :jido_connect_github
    status :available
    tags [:source_control, :issues, :developer_tools]

    capability :app_setup do
      kind :setup
      feature :github_app_manifest
      label "GitHub App setup"
      description "Manifest, installation callback, and installation-token helpers."
    end

    capability :webhook_verification do
      kind :webhook
      feature :webhook_verification
      label "Webhook verification"
      description "Signature verification and issue webhook normalization."
    end
  end

  auth do
    oauth2 :user do
      default? true
      owner :app_user
      subject :user
      label "GitHub OAuth user"
      authorize_url "https://github.com/login/oauth/authorize"
      token_url "https://github.com/login/oauth/access_token"
      callback_path "/integrations/github/oauth/callback"
      token_field :access_token
      refresh_token_field :refresh_token
      setup :oauth2_authorization_code
      credential_fields [:access_token, :refresh_token]
      lease_fields [:access_token]
      scopes ["repo", "read:user"]
      default_scopes ["read:user"]
      pkce? false
      refresh? false
      revoke? true
    end

    app_installation :installation do
      owner :installation
      subject :installation
      label "GitHub App installation"
      setup :github_app_installation
      credential_fields [:access_token]
      lease_fields [:access_token]
      scopes ["metadata:read", "issues:read", "issues:write"]
      default_scopes ["metadata:read", "issues:read"]
    end
  end

  policies do
    policy :repo_access do
      label "Repository access"

      description "Host verifies the actor may use this GitHub connection for the requested repository."

      subject {:input, :repo}
      owner {:connection, :owner}
      decision :allow_operation
    end
  end
end
