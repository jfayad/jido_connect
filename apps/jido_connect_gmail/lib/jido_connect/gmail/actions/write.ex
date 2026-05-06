defmodule Jido.Connect.Gmail.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @send_scope "https://www.googleapis.com/auth/gmail.send"
  @compose_scope "https://www.googleapis.com/auth/gmail.compose"
  @scope_resolver Jido.Connect.Gmail.ScopeResolver

  actions do
    action :send_message do
      id("google.gmail.message.send")
      resource(:message)
      verb(:send)
      data_classification(:message_content)
      label("Send Gmail message")
      description("Send an email through Gmail after validating recipients and body content.")
      handler(Jido.Connect.Gmail.Handlers.Actions.SendMessage)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@send_scope], resolver: @scope_resolver)
      end

      input do
        field(:to, {:array, :string}, required?: true)
        field(:cc, {:array, :string}, default: [])
        field(:bcc, {:array, :string}, default: [])
        field(:subject, :string, required?: true)
        field(:body_text, :string)
        field(:body_html, :string)
        field(:thread_id, :string)
        field(:in_reply_to, :string)
        field(:references, :string)
      end

      output do
        field(:message, :map)
      end
    end

    action :create_draft do
      id("google.gmail.draft.create")
      resource(:draft)
      verb(:create)
      data_classification(:message_content)
      label("Create Gmail draft")
      description("Create a Gmail draft after validating recipients and body content.")
      handler(Jido.Connect.Gmail.Handlers.Actions.CreateDraft)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@compose_scope], resolver: @scope_resolver)
      end

      input do
        field(:to, {:array, :string}, required?: true)
        field(:cc, {:array, :string}, default: [])
        field(:bcc, {:array, :string}, default: [])
        field(:subject, :string, required?: true)
        field(:body_text, :string)
        field(:body_html, :string)
        field(:thread_id, :string)
        field(:in_reply_to, :string)
        field(:references, :string)
      end

      output do
        field(:draft, :map)
      end
    end

    action :send_draft do
      id("google.gmail.draft.send")
      resource(:draft)
      verb(:send)
      data_classification(:message_content)
      label("Send Gmail draft")
      description("Send an existing Gmail draft.")
      handler(Jido.Connect.Gmail.Handlers.Actions.SendDraft)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@compose_scope], resolver: @scope_resolver)
      end

      input do
        field(:draft_id, :string, required?: true, example: "r123...")
      end

      output do
        field(:message, :map)
      end
    end
  end
end
