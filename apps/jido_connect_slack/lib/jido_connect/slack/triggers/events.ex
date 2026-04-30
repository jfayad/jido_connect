defmodule Jido.Connect.Slack.Triggers.Events do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
    webhook :app_mention do
      id "slack.event.app_mention"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "App mention"
      description "Receive Slack Events API app_mention callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      handler Jido.Connect.Slack.Handlers.Triggers.AppMentionEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["app_mentions:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
      end
    end

    webhook :public_channel_message do
      id "slack.event.message.channels"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Public channel message"

      description "Receive Slack Events API message.channels callbacks for plain public channel messages."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.PublicChannelMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
      end
    end
  end
end
