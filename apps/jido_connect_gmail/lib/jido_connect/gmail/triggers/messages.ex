defmodule Jido.Connect.Gmail.Triggers.Messages do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @scope_resolver Jido.Connect.Gmail.ScopeResolver

  triggers do
    poll :message_received do
      id("google.gmail.message.received")
      resource(:message)
      verb(:watch)
      data_classification(:message_content)
      label("Message received")
      description("Poll Gmail history for newly received message metadata.")
      interval_ms(300_000)
      checkpoint(:history_id)
      dedupe(%{key: [:message_id]})
      handler(Jido.Connect.Gmail.Handlers.Triggers.MessageReceivedPoller)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      config do
        field(:page_size, :integer, default: 100)
        field(:label_id, :string, default: "INBOX")
      end

      signal do
        field(:message_id, :string)
        field(:thread_id, :string)
        field(:history_id, :string)
        field(:label_ids, {:array, :string}, default: [])
        field(:snippet, :string)
        field(:internal_date, :string)
        field(:size_estimate, :integer)
        field(:headers, {:array, :map}, default: [])
        field(:message, :map)
      end
    end
  end
end
