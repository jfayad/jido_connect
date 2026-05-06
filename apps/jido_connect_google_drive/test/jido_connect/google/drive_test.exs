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
             "google.drive.file.get"
           ]
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
