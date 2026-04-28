defmodule Jido.Connect.Slack do
  @moduledoc """
  Slack integration authored with the `Jido.Connect` Spark DSL.

  This module compiles into hidden generated adapter modules under
  provider-specific Actions and Plugin namespaces.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Slack.Actions.Conversations,
      Jido.Connect.Slack.Actions.Messages
    ]

  integration do
    id :slack
    name "Slack"
    description "Slack workspace, channel, message, OAuth, and event tooling."
    category :collaboration
    docs ["https://docs.slack.dev/apis/web-api", "https://docs.slack.dev/events-api"]
  end

  catalog do
    package :jido_connect_slack
    status :available
    tags [:chat, :collaboration, :messaging]

    capability :app_manifest do
      kind :setup
      feature :slack_app_manifest
      label "Slack app manifest"
      description "Manifest-driven app setup for local and hosted OAuth installs."
    end

    capability :signed_requests do
      kind :webhook
      feature :signed_request_verification
      label "Signed request verification"
      description "Slack request signature verification and event normalization."
    end
  end

  auth do
    oauth2 :bot do
      default? true
      owner :tenant
      subject :bot
      label "Slack bot OAuth"
      authorize_url "https://slack.com/oauth/v2/authorize"
      token_url "https://slack.com/api/oauth.v2.access"
      callback_path "/integrations/slack/oauth/callback"
      token_field :access_token
      setup :oauth2_authorization_code
      credential_fields [:access_token]
      lease_fields [:access_token]
      scopes ["channels:read", "groups:read", "im:read", "mpim:read", "chat:write"]
      default_scopes ["channels:read", "chat:write"]
      pkce? false
      refresh? false
      revoke? false
    end
  end

  policies do
    policy :workspace_access do
      label "Workspace access"
      description "Host verifies the actor may use this Slack workspace connection."
      subject {:connection, :owner}
      owner {:connection, :owner}
      decision :allow_operation
    end
  end
end
