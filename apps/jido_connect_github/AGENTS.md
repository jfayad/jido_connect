# GitHub Connector Guidance

- Keep DSL fragments small and grouped by capability. Prefer separate files for
  repositories, issues, issue comments, pull requests, workflow runs, releases,
  triggers, and webhook event families.
- Keep the public `Jido.Connect.GitHub.Client` facade stable, but put endpoint
  implementations in API-area modules under `Jido.Connect.GitHub.Client.*`.
- Do not add a new `Client.Rest` or other catch-all client module. Add focused
  `Params`, `Response`, `Normalizer`, or API-area helpers only when they stay
  cohesive.
- Keep webhook verification separate from webhook event normalization. New event
  families should go into smaller normalizer modules instead of growing the
  facade.
