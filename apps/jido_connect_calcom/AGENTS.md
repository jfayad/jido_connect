# Cal.com Connector Guidance

- Keep Cal.com-specific DSL, handlers, schemas, normalized structs, and tests
  in this package. Shared OAuth, transport, scope, and pagination helpers
  belong in `jido_connect` core or in a future shared package.
- Keep Cal.com v2 API concerns in focused client modules as they are added.
- The `cal-api-version` header differs per endpoint group. Use the version map
  in `Jido.Connect.Calcom.Client.Transport` rather than hardcoding a single
  version.
- Prefer handwritten Req clients using `Jido.Connect.Provider.Transport` for
  the first implementation wave.
- Cal.com OAuth clients start in "pending" state and need Cal.com admin
  approval. API key auth (`cal_`-prefixed token) is recommended for development
  and CI.
- Webhook signature verification is not yet documented by Cal.com. Trigger
  authentication must be completed before webhook handlers process live
  payloads.
