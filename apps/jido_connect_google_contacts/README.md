# Jido Connect Google Contacts

Google Contacts provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps People API-specific DSL,
handlers, schemas, normalized structs, and tests in this package.

## Status

This scaffold declares the Contacts provider, OAuth profile, Contacts scope
resolver, normalized person/contact group structs, and package wiring. Contact
mutation actions, catalog packs, and expanded docs land in follow-up tasks in
the Google Contacts epic.

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

## Scopes

The connector starts with the narrow Contacts scopes from the shared Google
scope catalog:

- `contacts.readonly` for contact reads and search.
- `contacts` for contact and contact group mutations.
