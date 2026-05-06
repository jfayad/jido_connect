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
