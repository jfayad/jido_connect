defmodule Jido.Connect.Slack.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Slack.Webhook

  test "verifies valid Slack signature" do
    body = ~s({"type":"event_callback"})
    timestamp = "1700000000"
    signature = slack_signature("secret", timestamp, body)

    assert :ok =
             Webhook.verify_signature(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000
             )
  end

  test "verifies signed JSON requests" do
    body =
      Jason.encode!(%{
        type: "event_callback",
        team_id: "T123",
        event_id: "Ev123",
        event: %{
          type: "app_mention",
          channel: "C123",
          user: "U123",
          text: "<@U999> hello",
          ts: "1700000000.000100"
        }
      })

    timestamp = "1700000000"
    signature = slack_signature("secret", timestamp, body)

    assert {:ok, %{"type" => "event_callback"}} =
             Webhook.verify_request(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000
             )

    assert {:ok,
            %WebhookDelivery{
              provider: :slack,
              delivery_id: "Ev123",
              event: "app_mention",
              signature_state: :verified,
              duplicate?: true,
              payload: %{"type" => "event_callback"},
              normalized_signal: %{
                team_id: "T123",
                event_id: "Ev123",
                channel: "C123",
                text: "<@U999> hello",
                delivery: %{
                  provider: :slack,
                  event: "app_mention",
                  id: "Ev123",
                  duplicate?: true,
                  received_at: %DateTime{}
                }
              }
            }} =
             Webhook.verify_delivery(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000,
               seen_delivery_ids: ["Ev123"]
             )
  end

  test "rejects missing secret, stale timestamp, and invalid signature" do
    body = "{}"
    headers = %{"x-slack-signature" => "v0=bad", "x-slack-request-timestamp" => "1700000000"}

    assert {:error, %Error.AuthError{reason: :missing_signing_secret}} =
             Webhook.verify_signature(body, headers, nil, now: 1_700_000_000)

    assert {:error, %Error.AuthError{reason: :stale_timestamp}} =
             Webhook.verify_signature(body, headers, "secret", now: 1_700_001_000)

    assert {:error, %Error.AuthError{reason: :invalid_signature}} =
             Webhook.verify_signature(body, headers, "secret", now: 1_700_000_000)

    assert {:error, %Error.AuthError{reason: :missing_timestamp}} =
             Webhook.verify_signature(body, %{"x-slack-signature" => "v0=bad"}, "secret",
               now: 1_700_000_000
             )

    assert {:error, %Error.AuthError{reason: :invalid_timestamp}} =
             Webhook.verify_signature(
               body,
               %{"x-slack-signature" => "v0=bad", "x-slack-request-timestamp" => "nope"},
               "secret",
               now: 1_700_000_000
             )
  end

  test "returns url verification challenge" do
    assert {:ok, "challenge"} =
             Webhook.url_verification_challenge(%{
               "type" => "url_verification",
               "challenge" => "challenge"
             })

    assert {:error, %Error.ProviderError{provider: :slack, reason: :not_url_verification}} =
             Webhook.url_verification_challenge(%{"type" => "event_callback"})
  end

  test "normalizes app mention events" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev123",
      "event" => %{
        "type" => "app_mention",
        "channel" => "C123",
        "channel_type" => "channel",
        "user" => "U123",
        "text" => "<@U999> hello",
        "ts" => "1700000000.000100",
        "thread_ts" => "1700000000.000000"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev123",
              channel: "C123",
              channel_type: "channel",
              user: "U123",
              text: "<@U999> hello",
              ts: "1700000000.000100",
              thread_ts: "1700000000.000000"
            }} = Webhook.normalize_signal("app_mention", payload)

    assert {:ok, %{channel: "C123"}} = Webhook.normalize_event(payload)

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_event}} =
             Webhook.normalize_signal("unknown_event", %{
               "type" => "event_callback",
               "event" => %{"type" => "unknown_event"}
             })
  end

  test "normalizes public channel message events and rejects subtypes" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev456",
      "event" => %{
        "type" => "message",
        "channel" => "C123",
        "channel_type" => "channel",
        "user" => "U123",
        "text" => "hello",
        "ts" => "1700000000.000200",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000200"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev456",
              channel: "C123",
              channel_type: "channel",
              user: "U123",
              text: "hello",
              ts: "1700000000.000200",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000200"
            }} = Webhook.normalize_signal("message", payload)

    assert {:ok, %{channel: "C123"}} = Webhook.normalize_signal("message.channels", payload)
    assert {:ok, %{channel: "C123"}} = Webhook.normalize_event(payload)

    subtype_payload = put_in(payload, ["event", "subtype"], "message_changed")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_message_subtype}} =
             Webhook.normalize_signal("message", subtype_payload)

    im_payload = put_in(payload, ["event", "channel_type"], "im")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.channels", im_payload)
  end

  test "normalizes private channel message events and rejects other channel types" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev789",
      "event" => %{
        "type" => "message",
        "channel" => "G123",
        "channel_type" => "group",
        "user" => "U123",
        "text" => "private hello",
        "ts" => "1700000000.000300",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000300"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev789",
              channel: "G123",
              channel_type: "group",
              user: "U123",
              text: "private hello",
              ts: "1700000000.000300",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000300"
            }} = Webhook.normalize_signal("message.groups", payload)

    assert {:ok, %{channel: "G123"}} = Webhook.normalize_signal("message", payload)
    assert {:ok, %{channel: "G123"}} = Webhook.normalize_event(payload)

    public_payload = put_in(payload, ["event", "channel_type"], "channel")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.groups", public_payload)
  end

  test "normalizes direct message events with user and conversation metadata" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev901",
      "event" => %{
        "type" => "message",
        "channel" => "D123",
        "channel_type" => "im",
        "user" => "U123",
        "user_team" => "T123",
        "source_team" => "T123",
        "text" => "direct hello",
        "ts" => "1700000000.000400",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000400"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev901",
              channel: "D123",
              channel_type: "im",
              user: "U123",
              user_team: "T123",
              source_team: "T123",
              text: "direct hello",
              ts: "1700000000.000400",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000400",
              sender: %{id: "U123", team_id: "T123"},
              conversation: %{id: "D123", type: "im"}
            }} = Webhook.normalize_signal("message.im", payload)

    assert {:ok, %{channel: "D123", conversation: %{type: "im"}}} =
             Webhook.normalize_signal("message", payload)

    assert {:ok, %{channel: "D123", conversation: %{type: "im"}}} =
             Webhook.normalize_event(payload)

    group_payload = put_in(payload, ["event", "channel_type"], "group")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.im", group_payload)
  end

  test "normalizes multi-person direct message events with user and conversation metadata" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev902",
      "event" => %{
        "type" => "message",
        "channel" => "GMP123",
        "channel_type" => "mpim",
        "user" => "U123",
        "user_team" => "T123",
        "source_team" => "T456",
        "text" => "group direct hello",
        "ts" => "1700000000.000500",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000500"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev902",
              channel: "GMP123",
              channel_type: "mpim",
              user: "U123",
              user_team: "T123",
              source_team: "T456",
              text: "group direct hello",
              ts: "1700000000.000500",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000500",
              sender: %{id: "U123", team_id: "T123"},
              conversation: %{id: "GMP123", type: "mpim"}
            }} = Webhook.normalize_signal("message.mpim", payload)

    assert {:ok, %{channel: "GMP123", conversation: %{type: "mpim"}}} =
             Webhook.normalize_signal("message", payload)

    im_payload = put_in(payload, ["event", "channel_type"], "im")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.mpim", im_payload)
  end

  test "normalizes thread reply message events and rejects thread roots" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev903",
      "event" => %{
        "type" => "message",
        "channel" => "C123",
        "channel_type" => "channel",
        "user" => "U123",
        "text" => "thread reply",
        "ts" => "1700000000.000600",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000600"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev903",
              channel: "C123",
              channel_type: "channel",
              user: "U123",
              text: "thread reply",
              ts: "1700000000.000600",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000600"
            }} = Webhook.normalize_signal("message.thread_reply", payload)

    root_payload = put_in(payload, ["event", "ts"], "1700000000.000100")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :thread_root_message}} =
             Webhook.normalize_signal("message.thread_reply", root_payload)

    unthreaded_payload = update_in(payload, ["event"], &Map.delete(&1, "thread_ts"))

    assert {:error, %Error.ProviderError{provider: :slack, reason: :not_thread_reply}} =
             Webhook.normalize_signal("message.thread_reply", unthreaded_payload)
  end

  test "normalizes reaction added events with item metadata and actor identity" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev904",
      "event" => %{
        "type" => "reaction_added",
        "user" => "U123",
        "reaction" => "thumbsup",
        "item_user" => "U456",
        "item" => %{
          "type" => "message",
          "channel" => "C123",
          "ts" => "1700000000.000700"
        },
        "event_ts" => "1700000000.000800"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev904",
              user: "U123",
              reaction: "thumbsup",
              item_user: "U456",
              item: %{
                "type" => "message",
                "channel" => "C123",
                "ts" => "1700000000.000700"
              },
              item_type: "message",
              channel: "C123",
              ts: "1700000000.000700",
              event_ts: "1700000000.000800",
              actor: %{id: "U123", team_id: "T123"},
              item_owner: %{id: "U456", team_id: "T123"}
            }} = Webhook.normalize_signal("reaction_added", payload)

    assert {:ok, %{reaction: "thumbsup", item_type: "message"}} =
             Webhook.normalize_event(payload)

    file_payload =
      put_in(payload, ["event", "item"], %{
        "type" => "file_comment",
        "file" => "F123",
        "file_comment" => "Fc123"
      })

    assert {:ok,
            %{
              item_type: "file_comment",
              file: "F123",
              file_comment: "Fc123"
            }} = Webhook.normalize_signal("reaction_added", file_payload)
  end

  test "normalizes reaction removed events with item metadata and actor identity" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev905",
      "event" => %{
        "type" => "reaction_removed",
        "user" => "U123",
        "reaction" => "thumbsup",
        "item_user" => "U456",
        "item" => %{
          "type" => "message",
          "channel" => "C123",
          "ts" => "1700000000.000700"
        },
        "event_ts" => "1700000000.000900"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev905",
              user: "U123",
              reaction: "thumbsup",
              item_user: "U456",
              item: %{
                "type" => "message",
                "channel" => "C123",
                "ts" => "1700000000.000700"
              },
              item_type: "message",
              channel: "C123",
              ts: "1700000000.000700",
              event_ts: "1700000000.000900",
              actor: %{id: "U123", team_id: "T123"},
              item_owner: %{id: "U456", team_id: "T123"}
            }} = Webhook.normalize_signal("reaction_removed", payload)

    assert {:ok, %{reaction: "thumbsup", item_type: "message"}} =
             Webhook.normalize_event(payload)
  end

  test "invalid JSON payloads are provider errors" do
    body = "not json"
    timestamp = "1700000000"
    signature = slack_signature("secret", timestamp, body)

    assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_payload}} =
             Webhook.verify_request(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000
             )
  end

  defp slack_signature(secret, timestamp, body) do
    base = "v0:#{timestamp}:#{body}"

    signature =
      :hmac
      |> :crypto.mac(:sha256, secret, base)
      |> Base.encode16(case: :lower)

    "v0=#{signature}"
  end
end
