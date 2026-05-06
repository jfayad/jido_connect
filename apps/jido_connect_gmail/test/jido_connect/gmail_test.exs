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

    def list_history(
          %{
            start_history_id: "123",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          } = params,
          "token"
        )
        when not is_map_key(params, :page_token) do
      {:ok,
       %{
         history: [
           %{
             history_id: "124",
             messages_added: [
               Gmail.Message.new!(%{
                 message_id: "msg123",
                 thread_id: "thread123",
                 label_ids: ["INBOX", "UNREAD"],
                 snippet: "Budget update",
                 history_id: "124"
               }),
               Gmail.Message.new!(%{
                 message_id: "msg123",
                 thread_id: "thread123",
                 label_ids: ["INBOX", "UNREAD"],
                 snippet: "Budget update duplicate",
                 history_id: "124"
               })
             ]
           }
         ],
         next_page_token: "page-2",
         history_id: "125"
       }}
    end

    def list_history(
          %{
            start_history_id: "123",
            page_token: "page-2",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          },
          "token"
        ) do
      {:ok,
       %{
         history: [
           %{
             history_id: "125",
             messages_added: [
               Gmail.Message.new!(%{
                 message_id: "msg456",
                 thread_id: "thread456",
                 label_ids: ["INBOX"],
                 snippet: "Next update",
                 history_id: "125"
               })
             ]
           }
         ],
         history_id: "126"
       }}
    end

    def list_history(
          %{
            start_history_id: "126",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          },
          "token"
        ) do
      {:ok, %{history: [], history_id: "126"}}
    end

    def send_message(%{raw: raw, to: ["to@example.com"], subject: "Hello"}, "token")
        when is_binary(raw) do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "sent123",
         thread_id: "thread123",
         label_ids: ["SENT"]
       })}
    end

    def create_draft(%{raw: raw, to: ["to@example.com"], subject: "Hello"}, "token")
        when is_binary(raw) do
      {:ok,
       Gmail.Draft.new!(%{
         draft_id: "draft123",
         message:
           Gmail.Message.new!(%{
             message_id: "draft-message123",
             thread_id: "thread123"
           })
       })}
    end

    def send_draft(%{draft_id: "draft123"}, "token") do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "sent-draft123",
         thread_id: "thread123",
         label_ids: ["SENT"]
       })}
    end

    def create_label(%{name: "Customers", message_list_visibility: "show"}, "token") do
      {:ok,
       Gmail.Label.new!(%{
         label_id: "Label_123",
         name: "Customers",
         type: "user",
         message_list_visibility: "show"
       })}
    end

    def apply_message_labels(
          %{message_id: "msg123", add_label_ids: ["Label_123"], remove_label_ids: []},
          "token"
        ) do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "msg123",
         thread_id: "thread123",
         label_ids: ["INBOX", "Label_123"]
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
             "google.gmail.thread.get",
             "google.gmail.message.send",
             "google.gmail.draft.create",
             "google.gmail.draft.send",
             "google.gmail.label.create",
             "google.gmail.message.labels.apply"
           ]

    send_action = Enum.find(spec.actions, &(&1.id == "google.gmail.message.send"))
    assert send_action.risk == :external_write
    assert send_action.confirmation == :required_for_ai

    assert {:ok,
            %{
              id: "google.gmail.message.received",
              kind: :poll,
              checkpoint: :history_id,
              dedupe: %{key: [:message_id]},
              scope_resolver: Jido.Connect.Gmail.ScopeResolver
            }} =
             Connect.trigger(spec, "google.gmail.message.received")
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

  test "invokes send message through injected client and lease" do
    {context, lease} = context_and_lease(scopes: send_scopes())

    assert {:ok, %{message: %{message_id: "sent123", label_ids: ["SENT"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.send",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create draft through injected client and lease" do
    {context, lease} = context_and_lease(scopes: compose_scopes())

    assert {:ok, %{draft: %{draft_id: "draft123", message: %{message_id: "draft-message123"}}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.draft.create",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes send draft through injected client and lease" do
    {context, lease} = context_and_lease(scopes: compose_scopes())

    assert {:ok, %{message: %{message_id: "sent-draft123", label_ids: ["SENT"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.draft.send",
               %{draft_id: "draft123"},
               context: context,
               credential_lease: lease
             )
  end

  test "send and draft actions validate recipients and body inputs" do
    {context, lease} = context_and_lease(scopes: send_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_recipient,
              details: %{field: :to}
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.send",
               %{to: ["not-an-email"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "send action requires dynamic send-capable scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.send"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.send",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create label through injected client and lease" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:ok,
            %{
              label: %{
                label_id: "Label_123",
                name: "Customers",
                type: "user",
                message_list_visibility: "show"
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.create",
               %{name: " Customers ", message_list_visibility: "show"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes apply message labels through injected client and lease" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:ok, %{message: %{message_id: "msg123", label_ids: ["INBOX", "Label_123"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.labels.apply",
               %{message_id: "msg123", add_label_ids: [" Label_123 "]},
               context: context,
               credential_lease: lease
             )
  end

  test "label apply validates non-empty label changes" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_label_mutation,
              details: %{field: :labels}
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.labels.apply",
               %{message_id: "msg123"},
               context: context,
               credential_lease: lease
             )
  end

  test "label mutations require modify scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.modify"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.create",
               %{name: "Customers"},
               context: context,
               credential_lease: lease
             )
  end

  test "message received poll initializes checkpoint without replaying history" do
    {context, lease} = context_and_lease()

    assert {:ok, %{signals: [], checkpoint: "123"}} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "message received poll drains history pages, dedupes messages, and advances checkpoint" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  message_id: "msg123",
                  thread_id: "thread123",
                  history_id: "124",
                  label_ids: ["INBOX", "UNREAD"],
                  snippet: "Budget update",
                  message: %{message_id: "msg123", snippet: "Budget update"}
                },
                %{
                  message_id: "msg456",
                  thread_id: "thread456",
                  history_id: "125",
                  label_ids: ["INBOX"],
                  snippet: "Next update"
                }
              ],
              checkpoint: "126"
            }} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "123"
             )
  end

  test "message received poll emits no duplicates after checkpoint advances" do
    {context, lease} = context_and_lease()

    assert {:ok, %{signals: [], checkpoint: "126"}} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "126"
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

  defp send_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.send"
    ]
  end

  defp compose_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.compose"
    ]
  end

  defp modify_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.modify"
    ]
  end
end
