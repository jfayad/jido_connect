# Jido Connect Gmail

Gmail provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Gmail-specific DSL, handlers,
schemas, normalized structs, privacy boundaries, and tests in this package.

## Package Status

This package is being built through the Milestone 2 Gmail Beadwork epic. The
initial scaffold declares provider metadata and OAuth scope posture; schemas,
actions, catalog packs, and poll triggers are added by subsequent tasks.

## Privacy Boundary

Gmail data is sensitive by default. The connector classifies addresses,
subjects, snippets, headers, labels, and payload summaries as personal or
message content depending on the action. Normalized message, thread, and draft
structs intentionally avoid raw RFC822 bodies, Gmail `raw` payloads, and MIME
part `body.data` bytes unless a future action explicitly declares body access.
