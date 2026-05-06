defmodule Jido.Connect.Gmail.CatalogPacks do
  @moduledoc "Curated catalog packs for common Gmail tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @metadata_tools [
    "google.gmail.profile.get",
    "google.gmail.labels.list",
    "google.gmail.messages.list",
    "google.gmail.message.get",
    "google.gmail.threads.list",
    "google.gmail.thread.get",
    "google.gmail.message.received"
  ]

  @triage_tools @metadata_tools ++
                  [
                    "google.gmail.label.create",
                    "google.gmail.message.labels.apply"
                  ]

  @send_tools @metadata_tools ++
                [
                  "google.gmail.message.send",
                  "google.gmail.draft.create",
                  "google.gmail.draft.send"
                ]

  @doc "Returns all built-in Gmail catalog packs."
  def all, do: [metadata(), triage(), send()]

  @doc "Read-only Gmail metadata and message-received polling pack."
  def metadata do
    Pack.new!(%{
      id: :google_gmail_metadata,
      label: "Gmail metadata",
      description:
        "Read Gmail metadata and poll received message metadata without mutation tools.",
      filters: %{provider: :gmail},
      allowed_tools: @metadata_tools,
      metadata: %{package: :jido_connect_gmail, risk: :read}
    })
  end

  @doc "Gmail triage pack for reading and label management."
  def triage do
    Pack.new!(%{
      id: :google_gmail_triage,
      label: "Gmail triage",
      description:
        "Read Gmail metadata, poll received messages, and manage labels. Excludes send and draft tools.",
      filters: %{provider: :gmail},
      allowed_tools: @triage_tools,
      metadata: %{
        package: :jido_connect_gmail,
        excludes: [
          "google.gmail.message.send",
          "google.gmail.draft.create",
          "google.gmail.draft.send"
        ]
      }
    })
  end

  @doc "Gmail send pack for compose, draft, and send workflows."
  def send do
    Pack.new!(%{
      id: :google_gmail_send,
      label: "Gmail send",
      description:
        "Read Gmail metadata, poll received messages, and send or draft messages. Excludes label mutations.",
      filters: %{provider: :gmail},
      allowed_tools: @send_tools,
      metadata: %{
        package: :jido_connect_gmail,
        excludes: [
          "google.gmail.label.create",
          "google.gmail.message.labels.apply"
        ]
      }
    })
  end
end
