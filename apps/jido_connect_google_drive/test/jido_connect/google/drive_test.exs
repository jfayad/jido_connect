defmodule Jido.Connect.Google.DriveTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Drive

  defmodule FakeDriveClient do
    def list_files(
          %{
            query: "mimeType = 'application/pdf'",
            page_size: 25,
            spaces: "drive",
            include_items_from_all_drives: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       %{
         files: [
           Drive.File.new!(%{
             file_id: "file123",
             name: "Budget.pdf",
             mime_type: "application/pdf",
             parents: ["folder123"]
           })
         ],
         next_page_token: "next"
       }}
    end

    def get_file(
          %{file_id: "file123", supports_all_drives: false},
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "file123",
         name: "Budget.pdf",
         mime_type: "application/pdf",
         parents: ["folder123"]
       })}
    end

    def create_file(
          %{
            name: "Notes",
            mime_type: "text/plain",
            parents: ["folder123"],
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "created123",
         name: "Notes",
         mime_type: "text/plain",
         parents: ["folder123"]
       })}
    end

    def create_folder(
          %{name: "Reports", parents: ["root"], supports_all_drives: false},
          "token"
        ) do
      {:ok,
       Drive.Folder.new!(%{
         folder_id: "folder456",
         name: "Reports",
         parents: ["root"]
       })}
    end

    def copy_file(
          %{
            file_id: "file123",
            name: "Budget Copy.pdf",
            parents: ["folder123"],
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "copy123",
         name: "Budget Copy.pdf",
         mime_type: "application/pdf",
         parents: ["folder123"]
       })}
    end

    def update_file(
          %{file_id: "file123", name: "Renamed.pdf", supports_all_drives: false},
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "file123",
         name: "Renamed.pdf",
         mime_type: "application/pdf",
         parents: ["folder123"]
       })}
    end

    def export_file(
          %{file_id: "file123", mime_type: "text/csv", supports_all_drives: false},
          "token"
        ) do
      {:ok,
       %{
         file_id: "file123",
         mime_type: "text/csv",
         content: "name,total\nBudget,10\n",
         encoding: "utf-8",
         binary: false,
         size: 21
       }}
    end

    def download_file(%{file_id: "file123", supports_all_drives: false}, "token") do
      {:ok,
       %{
         file_id: "file123",
         mime_type: "application/pdf",
         content_base64: "AAEC",
         encoding: "base64",
         binary: true,
         size: 3
       }}
    end

    def delete_file(%{file_id: "file123", supports_all_drives: false}, "token") do
      {:ok, %{file_id: "file123", deleted?: true}}
    end

    def list_permissions(
          %{
            file_id: "file123",
            page_size: 100,
            supports_all_drives: false,
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok,
       %{
         permissions: [
           Drive.Permission.new!(%{
             permission_id: "perm123",
             type: "user",
             role: "reader",
             email_address: "reader@example.com"
           })
         ],
         next_page_token: "next-perm"
       }}
    end

    def create_permission(
          %{
            file_id: "file123",
            type: "user",
            role: "reader",
            email_address: "reader@example.com",
            transfer_ownership: false,
            supports_all_drives: false,
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok,
       Drive.Permission.new!(%{
         permission_id: "perm456",
         type: "user",
         role: "reader",
         email_address: "reader@example.com"
       })}
    end

    def get_start_page_token(%{supports_all_drives: false}, "token") do
      {:ok, %{start_page_token: "start-token"}}
    end

    def list_changes(
          %{
            page_token: "start-token",
            page_size: 100,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       %{
         changes: [
           Drive.Change.new!(%{
             change_id: "change123",
             file_id: "file123",
             removed?: false,
             time: "2026-05-05T12:00:00Z",
             change_type: "file",
             file:
               Drive.File.new!(%{
                 file_id: "file123",
                 name: "Budget.pdf",
                 mime_type: "application/pdf"
               })
           })
         ],
         new_start_page_token: "next-token"
       }}
    end
  end

  test "declares Google Drive provider metadata" do
    spec = Drive.integration()

    assert spec.id == :google_drive
    assert spec.package == :jido_connect_google_drive
    assert spec.name == "Google Drive"
    assert spec.tags == [:google, :workspace, :files, :productivity]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/drive.metadata.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/drive.file" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/drive.readonly" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "google.drive.files.list",
             "google.drive.file.get",
             "google.drive.file.create",
             "google.drive.folder.create",
             "google.drive.file.copy",
             "google.drive.file.update",
             "google.drive.file.export",
             "google.drive.file.download",
             "google.drive.file.delete",
             "google.drive.permissions.list",
             "google.drive.permission.create"
           ]

    delete_action = Enum.find(spec.actions, &(&1.id == "google.drive.file.delete"))
    assert delete_action.risk == :destructive
    assert delete_action.confirmation == :always

    create_permission = Enum.find(spec.actions, &(&1.id == "google.drive.permission.create"))
    assert create_permission.risk == :external_write
    assert create_permission.confirmation == :always

    assert Enum.find(create_permission.input, &(&1.name == :type)).enum == [
             "user",
             "group",
             "domain",
             "anyone"
           ]

    assert {:ok,
            %{
              id: "google.drive.file.changed",
              kind: :poll,
              checkpoint: :page_token,
              dedupe: %{key: [:change_id, :file_id]},
              scope_resolver: Jido.Connect.Google.Drive.ScopeResolver
            }} =
             Connect.trigger(spec, "google.drive.file.changed")
  end

  test "invokes list files through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              files: [
                %{
                  file_id: "file123",
                  name: "Budget.pdf",
                  mime_type: "application/pdf",
                  parents: ["folder123"]
                }
              ],
              next_page_token: "next"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.files.list",
               %{query: "mimeType = 'application/pdf'"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get file through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              file: %{
                file_id: "file123",
                name: "Budget.pdf",
                mime_type: "application/pdf"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.get",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "metadata read actions accept broader Drive readonly scope" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.readonly"
        ]
      )

    assert {:ok, %{file: %{file_id: "file123"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.get",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "fails before handler execution when required Drive scopes are missing" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/drive.metadata.readonly"]
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.get",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{file: %{file_id: "created123", name: "Notes", parents: ["folder123"]}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.create",
               %{name: "Notes", mime_type: "text/plain", parents: ["folder123"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create folder through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{folder: %{folder_id: "folder456", name: "Reports", parents: ["root"]}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.folder.create",
               %{name: "Reports", parents: ["root"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes copy file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{file: %{file_id: "copy123", name: "Budget Copy.pdf"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.copy",
               %{file_id: "file123", name: "Budget Copy.pdf", parents: ["folder123"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{file: %{file_id: "file123", name: "Renamed.pdf"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.update",
               %{file_id: "file123", name: "Renamed.pdf"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes export file through injected client and lease" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.readonly"
        ]
      )

    assert {:ok,
            %{
              file_content: %{
                file_id: "file123",
                mime_type: "text/csv",
                content: "name,total\nBudget,10\n",
                encoding: "utf-8",
                binary: false
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.export",
               %{file_id: "file123", mime_type: "text/csv"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes download file through injected client and lease" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.readonly"
        ]
      )

    assert {:ok,
            %{
              file_content: %{
                file_id: "file123",
                mime_type: "application/pdf",
                content_base64: "AAEC",
                encoding: "base64",
                binary: true
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.download",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{result: %{file_id: "file123", deleted?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.delete",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "content actions require file content scopes" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/drive.readonly"]
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.export",
               %{file_id: "file123", mime_type: "text/csv"},
               context: context,
               credential_lease: lease
             )
  end

  test "write actions require drive.file scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/drive.file"]
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.update",
               %{file_id: "file123", name: "Renamed.pdf"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list permissions through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              permissions: [
                %{
                  permission_id: "perm123",
                  type: "user",
                  role: "reader",
                  email_address: "reader@example.com"
                }
              ],
              next_page_token: "next-perm"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permissions.list",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create permission through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              permission: %{
                permission_id: "perm456",
                type: "user",
                role: "reader",
                email_address: "reader@example.com"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.create",
               %{
                 file_id: "file123",
                 type: "user",
                 role: "reader",
                 email_address: "reader@example.com"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "create permission validates role and target input" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_permission,
              details: %{field: :email_address}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.create",
               %{file_id: "file123", type: "user", role: "reader"},
               context: context,
               credential_lease: lease
             )
  end

  test "file change poll initializes checkpoint without replaying history" do
    {context, lease} = context_and_lease()

    assert {:ok, %{signals: [], checkpoint: "start-token"}} =
             Connect.poll(
               Drive.integration(),
               "google.drive.file.changed",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "file change poll emits normalized changes and advances checkpoint" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  change_id: "change123",
                  file_id: "file123",
                  removed: false,
                  time: "2026-05-05T12:00:00Z",
                  change_type: "file",
                  file: %{file_id: "file123", name: "Budget.pdf"}
                }
              ],
              checkpoint: "next-token"
            }} =
             Connect.poll(
               Drive.integration(),
               "google.drive.file.changed",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "start-token"
             )
  end

  defp write_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/drive.file"
    ]
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/drive.metadata.readonly"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_drive_client: FakeDriveClient},
        scopes: scopes
      })

    {context, lease}
  end
end
