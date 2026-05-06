# Google Contacts Connector Guidance

- Keep People API and Contacts-specific DSL, handlers, schemas, normalized
  structs, and tests in this package. Shared Google OAuth, account metadata,
  transport, scope, pagination, and provider error mapping belong in
  `jido_connect_google`.
- Prefer narrow Contacts scopes. Use `contacts.readonly` for read/search flows
  and `contacts` only for contact or group mutations.
- Normalize People API payloads into package structs before returning them from
  handlers.
- Destructive contact and group mutations must carry destructive risk and
  confirmation metadata in the DSL.
