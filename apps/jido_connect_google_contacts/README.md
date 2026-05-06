# Jido Connect Google Contacts

Google Contacts provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps People API-specific DSL,
handlers, schemas, normalized structs, and tests in this package.

## Status

This package declares the Contacts provider, OAuth profile, Contacts scope
resolver, normalized person/contact group structs, read and mutation actions,
and curated catalog packs.

## Actions

- `google.contacts.person.list`
- `google.contacts.person.get`
- `google.contacts.person.search`
- `google.contacts.person.create`
- `google.contacts.person.update`
- `google.contacts.person.delete`
- `google.contacts.group.list`
- `google.contacts.group.create`
- `google.contacts.group.update`

## Catalog Packs

- `:google_contacts_readonly` includes person reads, person search, and contact
  group reads without mutation tools.
- `:google_contacts_manager` includes the full Contacts surface: read tools,
  contact create/update/delete, and contact group create/update.

```elixir
Jido.Connect.Catalog.search_tools("contacts",
  modules: [Jido.Connect.Google.Contacts],
  packs: Jido.Connect.Google.Contacts.catalog_packs(),
  pack: :google_contacts_manager
)
```

## Scopes

The connector starts with the narrow Contacts scopes from the shared Google
scope catalog:

- `contacts.readonly` for contact reads and search.
- `contacts` for contact and contact group mutations.
