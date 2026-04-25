defmodule Jido.Connect.Slack.WebhookTest do
  use ExUnit.Case, async: true

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

  test "rejects missing secret, stale timestamp, and invalid signature" do
    body = "{}"
    headers = %{"x-slack-signature" => "v0=bad", "x-slack-request-timestamp" => "1700000000"}

    assert {:error, :missing_signing_secret} =
             Webhook.verify_signature(body, headers, nil, now: 1_700_000_000)

    assert {:error, :stale_timestamp} =
             Webhook.verify_signature(body, headers, "secret", now: 1_700_001_000)

    assert {:error, :invalid_signature} =
             Webhook.verify_signature(body, headers, "secret", now: 1_700_000_000)
  end

  test "returns url verification challenge" do
    assert {:ok, "challenge"} =
             Webhook.url_verification_challenge(%{
               "type" => "url_verification",
               "challenge" => "challenge"
             })
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
