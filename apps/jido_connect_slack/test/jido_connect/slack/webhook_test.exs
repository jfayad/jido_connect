defmodule Jido.Connect.Slack.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
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
    body = ~s({"type":"event_callback","event":{"type":"app_mention"}})
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
        "user" => "U123",
        "text" => "<@U999> hello",
        "ts" => "1700000000.000100"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev123",
              channel: "C123",
              user: "U123",
              text: "<@U999> hello",
              ts: "1700000000.000100"
            }} = Webhook.normalize_event(payload)

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_event}} =
             Webhook.normalize_event(%{
               "type" => "event_callback",
               "event" => %{"type" => "message"}
             })
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
