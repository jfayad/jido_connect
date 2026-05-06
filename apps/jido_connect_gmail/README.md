# Jido Connect Gmail

Gmail provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Gmail-specific DSL, handlers,
schemas, normalized structs, privacy boundaries, and tests in this package.

## Privacy Boundary

Gmail data is sensitive by default. The connector classifies addresses,
subjects, snippets, headers, labels, and payload summaries as personal or
message content depending on the action. Normalized message, thread, and draft
structs intentionally avoid raw RFC822 bodies, Gmail `raw` payloads, and MIME
part `body.data` bytes unless a future action explicitly declares body access.

## Actions

- `google.gmail.profile.get`
- `google.gmail.labels.list`
- `google.gmail.messages.list`
- `google.gmail.message.get`
- `google.gmail.threads.list`
- `google.gmail.thread.get`
- `google.gmail.message.send`
- `google.gmail.draft.create`
- `google.gmail.draft.send`
- `google.gmail.label.create`
- `google.gmail.message.labels.apply`

## Triggers

- `google.gmail.message.received`

The message poller initializes from the Gmail profile `historyId` without
replaying history, then drains Gmail history pages for `messageAdded` records
and advances the checkpoint to the returned mailbox `historyId`.

## Catalog Packs

- `:google_gmail_metadata` includes read-only profile, label, message, thread,
  and received-message poll tools.
- `:google_gmail_triage` adds label creation and message label mutation. It
  intentionally excludes send and draft tools.
- `:google_gmail_send` adds message send and draft workflows. It intentionally
  excludes label mutation tools.

```elixir
Jido.Connect.Catalog.search_tools("gmail",
  modules: [Jido.Connect.Gmail],
  packs: Jido.Connect.Gmail.catalog_packs(),
  pack: :google_gmail_triage
)
```

## Scopes

The connector prefers narrow Gmail scopes:

- `gmail.metadata` for profile, labels, metadata reads, and received-message
  polling.
- `gmail.readonly` or `gmail.modify` can satisfy metadata-read tools when a
  host already has broader grants.
- `gmail.send` for direct send, with `gmail.compose` or `gmail.modify` accepted
  when already granted.
- `gmail.compose` for draft create/send, with `gmail.modify` accepted when
  already granted.
- `gmail.modify` for label creation and label application/removal.
