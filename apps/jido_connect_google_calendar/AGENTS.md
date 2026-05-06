# Google Calendar Connector Guidance

- Keep Calendar scopes narrow. Prefer event-read, event-write, and freebusy scopes before broad Calendar scopes.
- Normalize Calendar API payloads into package structs before returning them from handlers.
- Destructive event mutations must carry risk or confirmation metadata in the DSL.
- Poll triggers should initialize checkpoints without replaying existing calendar history.
