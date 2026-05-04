defmodule Jido.Connect.Slack.Triggers.Events.Channels do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
    webhook :channel_created do
      id "slack.event.channel_created"
      resource :channel
      verb :watch
      data_classification :workspace_metadata
      label "Channel created"
      description "Receive Slack Events API channel_created callbacks with channel metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.ChannelCreatedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel_id, :string
        field :channel, :map
        field :user, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :channel_rename do
      id "slack.event.channel_rename"
      resource :channel
      verb :watch
      data_classification :workspace_metadata
      label "Channel rename"
      description "Receive Slack Events API channel_rename callbacks with channel metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.ChannelRenameEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel_id, :string
        field :channel, :map
        field :user, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :channel_archive do
      id "slack.event.channel_archive"
      resource :channel
      verb :watch
      data_classification :workspace_metadata
      label "Channel archive"
      description "Receive Slack Events API channel_archive callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.ChannelArchiveEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel_id, :string
        field :channel, :map
        field :user, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :channel_unarchive do
      id "slack.event.channel_unarchive"
      resource :channel
      verb :watch
      data_classification :workspace_metadata
      label "Channel unarchive"
      description "Receive Slack Events API channel_unarchive callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.ChannelUnarchiveEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel_id, :string
        field :channel, :map
        field :user, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :member_joined_channel do
      id "slack.event.member_joined_channel"
      resource :channel_member
      verb :watch
      data_classification :workspace_metadata
      label "Member joined channel"
      description "Receive Slack Events API member_joined_channel callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel_id, :user, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.MemberJoinedChannelEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :inviter, :string
        field :event_ts, :string
        field :actor, :map
        field :inviter_user, :map
      end
    end

    webhook :member_left_channel do
      id "slack.event.member_left_channel"
      resource :channel_member
      verb :watch
      data_classification :workspace_metadata
      label "Member left channel"
      description "Receive Slack Events API member_left_channel callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel_id, :user, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.MemberLeftChannelEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :event_ts, :string
        field :actor, :map
      end
    end
  end
end
