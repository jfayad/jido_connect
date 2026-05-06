# Jido Connect Google Drive

Google Drive provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Drive-specific DSL, handlers,
schemas, normalized structs, and tests in this package.

## Actions

- `google.drive.files.list`
- `google.drive.file.get`
- `google.drive.file.create`
- `google.drive.folder.create`
- `google.drive.file.copy`
- `google.drive.file.update`
- `google.drive.file.export`
- `google.drive.file.download`
- `google.drive.file.delete`
- `google.drive.permissions.list`
- `google.drive.permission.create`

## Triggers

- `google.drive.file.changed`

The change poller initializes from Drive `startPageToken` without replaying
history, then advances checkpoints through `nextPageToken` or
`newStartPageToken`.

## Catalog Packs

- `:google_drive_readonly` includes metadata reads, content reads, permission
  reads, and file-change polling.
- `:google_drive_file_writer` adds common file metadata writes and folder
  creation. It intentionally excludes destructive delete and permission sharing.

```elixir
Jido.Connect.Catalog.search_tools("drive",
  modules: [Jido.Connect.Google.Drive],
  packs: Jido.Connect.Google.Drive.catalog_packs(),
  pack: :google_drive_file_writer
)
```

## Scopes

The connector prefers narrow Drive scopes:

- `drive.metadata.readonly` for metadata reads, permission listing, and change
  polling.
- `drive.readonly` for file content export/download.
- `drive.file` for app-managed file writes, deletes, and permission creation.
