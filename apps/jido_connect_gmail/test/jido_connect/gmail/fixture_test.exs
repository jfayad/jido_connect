defmodule Jido.Connect.Gmail.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Gmail.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes common Gmail message metadata fixture" do
    payload = fixture!("message_common.json")

    assert {:ok, message} = Normalizer.message(payload)
    assert message.message_id == "18c-common"
    assert message.thread_id == "thread-common"
    assert message.label_ids == ["INBOX", "UNREAD"]

    assert message.headers == [
             %{name: "From", value: "sender@example.com"},
             %{name: "Subject", value: "Quarterly budget"}
           ]

    assert message.payload_summary.body_size == 0
    assert [%{mime_type: "text/plain", body_size: 128}] = message.payload_summary.parts
  end

  test "normalizes edge Gmail message fixture without raw body leakage" do
    payload = fixture!("message_edge_raw_body.json")

    assert {:ok, message} = Normalizer.message(payload)
    assert message.history_id == "789"
    assert message.label_ids == []
    assert message.headers == [%{name: "Subject", value: "Sensitive"}]
    assert message.payload_summary.body_size == 321

    refute inspect(message) =~ "raw-message-secret"
    refute inspect(message) =~ "encoded-body-secret"
    refute inspect(message) =~ "part-secret"
  end

  defp fixture!(name) do
    ConnectorContracts.google_fixture!(:gmail, name, __DIR__)
  end
end
