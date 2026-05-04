# Slack Connector Guidance

- Keep DSL fragments small and grouped by capability. Prefer separate files for
  conversations, messages, files, reactions, pins, users, identity, and Slack
  Events API families.
- Keep the public `Jido.Connect.Slack.Client` facade stable, but put endpoint
  implementations in API-area modules under `Jido.Connect.Slack.Client.*`.
- Do not add a new `Client.Rest` or other catch-all client module. Add focused
  `Params`, `Response`, `Normalizer`, or API-area helpers only when they stay
  cohesive.
- Keep signed-request verification separate from event normalization. New Slack
  event families should go into smaller normalizer modules instead of growing the
  facade.
