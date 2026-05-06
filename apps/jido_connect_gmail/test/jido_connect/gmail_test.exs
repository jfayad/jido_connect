defmodule Jido.Connect.GmailTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Gmail

  defmodule FakeGmailClient do
    def get_profile(%{}, "token") do
      {:ok,
       Gmail.Profile.new!(%{
         email_address: "user@example.com",
         messages_total: 10,
         threads_total: 5,
         history_id: "123"
       })}
    end

    def list_labels(%{}, "token") do
      {:ok,
       %{
         labels: [
           Gmail.Label.new!(%{
             label_id: "INBOX",
             name: "INBOX",
             type: "system"
           })
         ]
       }}
    end

    def list_messages(
          %{
            query: "from:sender@example.com",
            label_ids: ["INBOX"],
            page_size: 25,
            include_spam_trash: false
          },
          "token"
        ) do
      {:ok,
       %{
         messages: [
           Gmail.Message.new!(%{
             message_id: "msg123",
             thread_id: "thread123",
             label_ids: ["INBOX"],
             snippet: "Budget update"
           })
         ],
         next_page_token: "next",
         result_size_estimate: 1
       }}
    end

    def get_message(%{message_id: "msg123", metadata_headers: ["From", "Subject"]}, "token") do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "msg123",
         thread_id: "thread123",
         label_ids: ["INBOX"],
         snippet: "Budget update",
         headers: [
           %{name: "From", value: "sender@example.com"},
           %{name: "Subject", value: "Budget"}
         ]
       })}
    end

    def list_threads(
          %{
            query: "label:inbox",
            label_ids: ["INBOX"],
            page_size: 25,
            include_spam_trash: false
          },
          "token"
        ) do
      {:ok,
       %{
         threads: [
           Gmail.Thread.new!(%{
             thread_id: "thread123",
             history_id: "456",
             snippet: "Budget update"
           })
         ],
         next_page_token: "next-thread",
         result_size_estimate: 1
       }}
    end

    def get_thread(%{thread_id: "thread123", metadata_headers: ["From", "Subject"]}, "token") do
      {:ok,
       Gmail.Thread.new!(%{
         thread_id: "thread123",
         history_id: "456",
         snippet: "Budget update",
         messages: [
           Gmail.Message.new!(%{
             message_id: "msg123",
             thread_id: "thread123",
             snippet: "Budget update"
           })
         ]
       })}
    end
  end

  test "declares Gmail provider metadata" do
    spec = Gmail.integration()

    assert spec.id == :gmail
    assert spec.package == :jido_connect_gmail
    assert spec.name == "Gmail"
    assert spec.category == :email
    assert spec.tags == [:google, :workspace, :email, :productivity]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/gmail.metadata" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.send" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.compose" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.modify" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "google.gmail.profile.get",
             "google.gmail.labels.list",
             "google.gmail.messages.list",
             "google.gmail.message.get",
             "google.gmail.threads.list",
             "google.gmail.thread.get"
           ]

    assert spec.triggers == []
  end

  test "invokes get profile through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              profile: %{
                email_address: "user@example.com",
                messages_total: 10,
                threads_total: 5,
                history_id: "123"
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.profile.get",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list labels through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              labels: [
                %{
                  label_id: "INBOX",
                  name: "INBOX",
                  type: "system"
                }
              ]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.labels.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "metadata actions accept broader Gmail readonly scope" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/gmail.readonly"
        ]
      )

    assert {:ok, %{profile: %{email_address: "user@example.com"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.profile.get",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "fails before handler execution when required Gmail scopes are missing" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.metadata"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.profile.get",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list messages through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              messages: [
                %{
                  message_id: "msg123",
                  thread_id: "thread123",
                  snippet: "Budget update"
                }
              ],
              next_page_token: "next",
              result_size_estimate: 1
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.messages.list",
               %{query: "from:sender@example.com", label_ids: ["INBOX"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get message metadata through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              message: %{
                message_id: "msg123",
                thread_id: "thread123",
                snippet: "Budget update",
                headers: [
                  %{name: "From", value: "sender@example.com"},
                  %{name: "Subject", value: "Budget"}
                ]
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.get",
               %{message_id: "msg123", metadata_headers: ["From", "Subject"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list threads through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              threads: [
                %{
                  thread_id: "thread123",
                  history_id: "456",
                  snippet: "Budget update"
                }
              ],
              next_page_token: "next-thread",
              result_size_estimate: 1
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.threads.list",
               %{query: "label:inbox", label_ids: ["INBOX"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get thread metadata through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              thread: %{
                thread_id: "thread123",
                history_id: "456",
                messages: [%{message_id: "msg123"}]
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.get",
               %{thread_id: "thread123", metadata_headers: ["From", "Subject"]},
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
        "https://www.googleapis.com/auth/gmail.metadata"
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
        fields: %{access_token: "token", gmail_client: FakeGmailClient},
        scopes: scopes
      })

    {context, lease}
  end
end
