defmodule Jido.Connect.Slack.Triggers.Events.Messages do
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

    webhook :private_channel_message do
      id "slack.event.message.groups"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Private channel message"

      description "Receive Slack Events API message.groups callbacks for plain private channel messages. Requires Slack groups:history for private channel history events."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.PrivateChannelMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["groups:history"]
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

    webhook :direct_message do
      id "slack.event.message.im"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Direct message"

      description "Receive Slack Events API message.im callbacks for plain direct messages. Requires Slack im:history for direct message history events."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.DirectMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["im:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :user_team, :string
        field :source_team, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :sender, :map
        field :conversation, :map
      end
    end

    webhook :multi_person_direct_message do
      id "slack.event.message.mpim"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Multi-person direct message"

      description "Receive Slack Events API message.mpim callbacks for plain multi-person direct messages. Requires Slack mpim:history for multi-person direct message history events."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.MultiPersonDirectMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["mpim:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :user_team, :string
        field :source_team, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :sender, :map
        field :conversation, :map
      end
    end

    webhook :thread_reply do
      id "slack.event.message.thread_reply"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Thread reply"

      description "Receive Slack Events API message callbacks for plain thread replies, excluding thread root messages."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :thread_ts, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.ThreadReplyEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:history", "groups:history", "im:history", "mpim:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :user_team, :string
        field :source_team, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :sender, :map
        field :conversation, :map
      end
    end
  end
end
