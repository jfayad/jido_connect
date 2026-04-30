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

    webhook :reaction_added do
      id "slack.event.reaction_added"
      resource :reaction
      verb :watch
      data_classification :workspace_content
      label "Reaction added"

      description "Receive Slack Events API reaction_added callbacks with item and actor metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :user, :reaction, :item_type, :channel, :ts, :event_ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.ReactionAddedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["reactions:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :user, :string
        field :reaction, :string
        field :item_user, :string
        field :item, :map
        field :item_type, :string
        field :channel, :string
        field :ts, :string
        field :file, :string
        field :file_comment, :string
        field :event_ts, :string
        field :actor, :map
        field :item_owner, :map
      end
    end

    webhook :reaction_removed do
      id "slack.event.reaction_removed"
      resource :reaction
      verb :watch
      data_classification :workspace_content
      label "Reaction removed"

      description "Receive Slack Events API reaction_removed callbacks with item and actor metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :user, :reaction, :item_type, :channel, :ts, :event_ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.ReactionRemovedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["reactions:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :user, :string
        field :reaction, :string
        field :item_user, :string
        field :item, :map
        field :item_type, :string
        field :channel, :string
        field :ts, :string
        field :file, :string
        field :file_comment, :string
        field :event_ts, :string
        field :actor, :map
        field :item_owner, :map
      end
    end

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

    webhook :file_created do
      id "slack.event.file_created"
      resource :file
      verb :watch
      data_classification :workspace_content
      label "File created"
      description "Receive Slack Events API file_created callbacks with file metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :file_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.FileCreatedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :file_id, :string
        field :file, :map
        field :user_id, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :file_shared do
      id "slack.event.file_shared"
      resource :file
      verb :watch
      data_classification :workspace_content
      label "File shared"
      description "Receive Slack Events API file_shared callbacks with file and channel metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :file_id, :channel_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.FileSharedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :file_id, :string
        field :file, :map
        field :user_id, :string
        field :channel_id, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :file_public do
      id "slack.event.file_public"
      resource :file
      verb :watch
      data_classification :workspace_content
      label "File public"
      description "Receive Slack Events API file_public callbacks with file metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :file_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.FilePublicEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :file_id, :string
        field :file, :map
        field :user_id, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :file_deleted do
      id "slack.event.file_deleted"
      resource :file
      verb :watch
      data_classification :workspace_content
      label "File deleted"
      description "Receive Slack Events API file_deleted callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :file_id, :event_ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.FileDeletedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :file_id, :string
        field :file, :map
        field :user_id, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

    webhook :file_change do
      id "slack.event.file_change"
      resource :file
      verb :watch
      data_classification :workspace_content
      label "File change"
      description "Receive Slack Events API file_change callbacks with file metadata."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :file_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.FileChangeEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :file_id, :string
        field :file, :map
        field :user_id, :string
        field :event_ts, :string
        field :actor, :map
      end
    end

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
