defmodule Jido.Connect.Slack.Triggers.Events.Reactions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
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
  end
end
