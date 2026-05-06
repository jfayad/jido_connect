# Jido Connect Google Contacts

Google Contacts provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps People API-specific DSL,
handlers, schemas, normalized structs, and tests in this package.

## Status

This scaffold declares the Contacts provider, OAuth profile, Contacts scope
resolver, and package wiring. Person, contact mutation, contact group, catalog
pack, and docs work lands in follow-up tasks in the Google Contacts epic.

## Scopes

The connector starts with the narrow Contacts scopes from the shared Google
scope catalog:

- `contacts.readonly` for contact reads and search.
- `contacts` for contact and contact group mutations.
