defmodule Jido.Connect.Slack.Triggers.Events.Files do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
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
  end
end
