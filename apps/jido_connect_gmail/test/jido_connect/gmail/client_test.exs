defmodule Jido.Connect.Gmail.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Gmail.{Client, Label, Message, Profile, Thread}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_gmail, :gmail_api_base_url, "https://gmail.test")
    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_gmail, :gmail_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets Gmail profile" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/profile"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      Req.Test.json(conn, %{
        "emailAddress" => "user@example.com",
        "messagesTotal" => 10,
        "threadsTotal" => 5,
        "historyId" => "123"
      })
    end)

    assert {:ok, %Profile{} = profile} = Client.get_profile(%{}, "token")
    assert profile.email_address == "user@example.com"
    assert profile.messages_total == 10
  end

  test "lists Gmail labels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/labels"

      Req.Test.json(conn, %{
        "labels" => [
          %{
            "id" => "INBOX",
            "name" => "INBOX",
            "type" => "system"
          }
        ]
      })
    end)

    assert {:ok, %{labels: [%Label{} = label]}} = Client.list_labels(%{}, "token")
    assert label.label_id == "INBOX"
    assert label.name == "INBOX"
  end

  test "lists Gmail messages" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages"
      assert conn.query_params["q"] == "from:sender@example.com"
      assert conn.query_params["labelIds"] == "INBOX"
      assert conn.query_params["maxResults"] == "10"
      assert conn.query_params["includeSpamTrash"] == "false"

      Req.Test.json(conn, %{
        "messages" => [
          %{"id" => "msg123", "threadId" => "thread123"}
        ],
        "nextPageToken" => "next",
        "resultSizeEstimate" => 1
      })
    end)

    assert {:ok, %{messages: [%Message{} = message], next_page_token: "next"}} =
             Client.list_messages(
               %{
                 query: "from:sender@example.com",
                 label_ids: ["INBOX"],
                 page_size: 10,
                 include_spam_trash: false
               },
               "token"
             )

    assert message.message_id == "msg123"
    assert message.thread_id == "thread123"
  end

  test "returns provider errors for malformed Gmail list items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages"

      Req.Test.json(conn, %{
        "messages" => [
          %{"threadId" => "thread123"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_messages(%{}, "token")
  end

  test "gets Gmail message metadata without body data" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages/msg123"
      assert conn.query_params["format"] == "metadata"
      assert conn.query_params["metadataHeaders"] == "Subject"

      Req.Test.json(conn, message_payload())
    end)

    assert {:ok, %Message{} = message} =
             Client.get_message(%{message_id: "msg123", metadata_headers: ["Subject"]}, "token")

    assert message.message_id == "msg123"
    assert [%{name: "Subject", value: "Budget"}] = message.headers
    refute inspect(message) =~ "body-bytes"
  end

  test "lists Gmail threads" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/threads"
      assert conn.query_params["q"] == "label:inbox"
      assert conn.query_params["labelIds"] == "INBOX"

      Req.Test.json(conn, %{
        "threads" => [
          %{"id" => "thread123", "historyId" => "456"}
        ],
        "nextPageToken" => "next-thread",
        "resultSizeEstimate" => 1
      })
    end)

    assert {:ok, %{threads: [%Thread{} = thread], next_page_token: "next-thread"}} =
             Client.list_threads(%{query: "label:inbox", label_ids: ["INBOX"]}, "token")

    assert thread.thread_id == "thread123"
    assert thread.history_id == "456"
  end

  test "gets Gmail thread metadata without body data" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/threads/thread123"
      assert conn.query_params["format"] == "metadata"
      assert conn.query_params["metadataHeaders"] == "Subject"

      Req.Test.json(conn, %{
        "id" => "thread123",
        "historyId" => "456",
        "messages" => [message_payload()]
      })
    end)

    assert {:ok, %Thread{} = thread} =
             Client.get_thread(%{thread_id: "thread123", metadata_headers: ["Subject"]}, "token")

    assert thread.thread_id == "thread123"
    assert [%Message{message_id: "msg123"}] = thread.messages
    refute inspect(thread) =~ "body-bytes"
  end

  test "returns provider errors for malformed Gmail single-object responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/threads/thread123"

      Req.Test.json(conn, %{
        "id" => "thread123",
        "messages" => [
          %{"threadId" => "thread123"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.get_thread(%{thread_id: "thread123"}, "token")
  end

  test "lists Gmail history message additions without body data" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/history"
      assert conn.query_params["startHistoryId"] == "123"
      assert conn.query_params["labelId"] == "INBOX"
      assert conn.query_params["maxResults"] == "50"
      assert conn.query_params["pageToken"] == "page-2"
      assert conn.query_params["historyTypes"] == "messageAdded"

      Req.Test.json(conn, %{
        "history" => [
          %{
            "id" => "124",
            "messagesAdded" => [
              %{
                "message" => message_payload()
              }
            ]
          }
        ],
        "historyId" => "125"
      })
    end)

    assert {:ok, %{history: [%{history_id: "124", messages_added: [%Message{} = message]}]}} =
             Client.list_history(
               %{
                 start_history_id: "123",
                 label_id: "INBOX",
                 page_size: 50,
                 page_token: "page-2",
                 history_types: ["messageAdded"]
               },
               "token"
             )

    assert message.message_id == "msg123"
    refute inspect(message) =~ "body-bytes"
  end

  test "returns provider errors for malformed Gmail history records" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/history"

      Req.Test.json(conn, %{
        "history" => [
          %{"id" => "124", "messagesAdded" => nil}
        ],
        "historyId" => "125"
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} =
             Client.list_history(
               %{start_history_id: "123", history_types: ["messageAdded"]},
               "token"
             )
  end

  test "sends Gmail messages" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/messages/send"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "raw" => "encoded-message",
               "threadId" => "thread123"
             }

      Req.Test.json(conn, %{
        "id" => "sent123",
        "threadId" => "thread123",
        "labelIds" => ["SENT"]
      })
    end)

    assert {:ok, %Message{} = message} =
             Client.send_message(%{raw: "encoded-message", thread_id: "thread123"}, "token")

    assert message.message_id == "sent123"
    assert message.label_ids == ["SENT"]
  end

  test "creates Gmail drafts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/drafts"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "message" => %{"raw" => "encoded-message", "threadId" => "thread123"}
             }

      Req.Test.json(conn, %{
        "id" => "draft123",
        "message" => %{"id" => "draft-message123", "threadId" => "thread123"}
      })
    end)

    assert {:ok, draft} =
             Client.create_draft(%{raw: "encoded-message", thread_id: "thread123"}, "token")

    assert draft.draft_id == "draft123"
    assert draft.message.message_id == "draft-message123"
  end

  test "sends Gmail drafts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/drafts/send"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"id" => "draft123"}

      Req.Test.json(conn, %{
        "id" => "sent-draft123",
        "threadId" => "thread123",
        "labelIds" => ["SENT"]
      })
    end)

    assert {:ok, %Message{} = message} = Client.send_draft(%{draft_id: "draft123"}, "token")
    assert message.message_id == "sent-draft123"
  end

  test "creates Gmail labels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/labels"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Customers",
               "messageListVisibility" => "show",
               "labelListVisibility" => "labelShow"
             }

      Req.Test.json(conn, %{
        "id" => "Label_123",
        "name" => "Customers",
        "type" => "user",
        "messageListVisibility" => "show"
      })
    end)

    assert {:ok, %Label{} = label} =
             Client.create_label(
               %{
                 name: "Customers",
                 message_list_visibility: "show",
                 label_list_visibility: "labelShow"
               },
               "token"
             )

    assert label.label_id == "Label_123"
    assert label.name == "Customers"
  end

  test "applies Gmail message labels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/messages/msg123/modify"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "addLabelIds" => ["Label_123"],
               "removeLabelIds" => []
             }

      Req.Test.json(conn, %{
        "id" => "msg123",
        "threadId" => "thread123",
        "labelIds" => ["INBOX", "Label_123"]
      })
    end)

    assert {:ok, %Message{} = message} =
             Client.apply_message_labels(
               %{message_id: "msg123", add_label_ids: ["Label_123"], remove_label_ids: []},
               "token"
             )

    assert message.label_ids == ["INBOX", "Label_123"]
  end

  defp message_payload do
    %{
      "id" => "msg123",
      "threadId" => "thread123",
      "labelIds" => ["INBOX"],
      "snippet" => "Budget update",
      "payload" => %{
        "mimeType" => "text/plain",
        "headers" => [%{"name" => "Subject", "value" => "Budget"}],
        "body" => %{"size" => 12, "data" => "body-bytes"}
      }
    }
  end
end
