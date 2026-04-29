# GitHub Webhooks

Use `Jido.Connect.GitHub.Webhook.verify_request/3` to verify
`X-Hub-Signature-256`, parse delivery metadata, and decode JSON payloads.

Use `normalize_signal/2` to turn supported GitHub events into stable
signal-shaped maps. Issue open events match the poll sensor shape, and push
events include repository, ref, commits, pusher, and delivery metadata when
normalized from a verified delivery.

Hosts own delivery dedupe and persistence.
