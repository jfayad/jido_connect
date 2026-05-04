defmodule Jido.Connect.Slack.Triggers.Events.Lifecycle do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
    webhook :app_uninstalled do
      id "slack.event.app_uninstalled"
      resource :app
      verb :watch
      data_classification :workspace_metadata
      label "App uninstalled"
      description "Receive Slack Events API app_uninstalled callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :api_app_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.AppUninstalledEvent

      access do
        auth :bot
        policies [:workspace_access]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :api_app_id, :string
        field :event_time, :integer
        field :authorizations, {:array, :map}
      end
    end

    webhook :tokens_revoked do
      id "slack.event.tokens_revoked"
      resource :token
      verb :watch
      data_classification :workspace_metadata
      label "Tokens revoked"
      description "Receive Slack Events API tokens_revoked callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :api_app_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.TokensRevokedEvent

      access do
        auth :bot
        policies [:workspace_access]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :api_app_id, :string
        field :event_time, :integer
        field :tokens, :map
        field :oauth_user_ids, {:array, :string}
        field :bot_user_ids, {:array, :string}
      end
    end

    webhook :scope_denied do
      id "slack.event.scope_denied"
      resource :scope
      verb :watch
      data_classification :workspace_metadata
      label "Scope denied"
      description "Receive Slack Events API scope_denied callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :api_app_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.ScopeDeniedEvent

      access do
        auth :bot
        policies [:workspace_access]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :api_app_id, :string
        field :event_time, :integer
        field :scope, :string
        field :scopes, {:array, :string}
        field :user, :string
        field :trigger_id, :string
        field :event_ts, :string
      end
    end

    webhook :app_home_opened do
      id "slack.event.app_home_opened"
      resource :app_home
      verb :watch
      data_classification :workspace_content
      label "App home opened"
      description "Receive Slack Events API app_home_opened callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :user, :channel, :event_ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.AppHomeOpenedEvent

      access do
        auth :bot
        policies [:workspace_access]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :api_app_id, :string
        field :user, :string
        field :channel, :string
        field :tab, :string
        field :view, :map
        field :event_ts, :string
        field :actor, :map
        field :conversation, :map
      end
    end
  end
end
