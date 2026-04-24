# GitHub Webhooks

Use `Jido.Connect.GitHub.Webhook.verify_request/3` to verify
`X-Hub-Signature-256`, parse delivery metadata, and decode JSON payloads.

Use `normalize_signal/2` to turn supported GitHub events into the same
signal-shaped maps produced by poll sensors.

Hosts own delivery dedupe and persistence.
