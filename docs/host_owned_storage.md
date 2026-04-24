# Host-Owned Storage

`jido_connect` intentionally does not ship Ecto schemas, migrations, storage
behaviours, or adapters.

Hosts own:

- durable connection records
- credential storage
- OAuth state/session persistence
- webhook delivery dedupe
- run and event audit history

The package contracts are `Jido.Connect.Connection`,
`Jido.Connect.CredentialLease`, `Jido.Connect.Run`, and `Jido.Connect.Event`.
