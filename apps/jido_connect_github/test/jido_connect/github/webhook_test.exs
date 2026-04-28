defmodule Jido.Connect.GitHub.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.GitHub.Webhook

  test "verifies valid signature" do
    body = ~s({"action":"opened"})
    signature = "sha256=" <> hmac("secret", body)

    assert :ok = Webhook.verify_signature(body, signature, "secret")
  end

  test "verifies requests and parses headers" do
    body = ~s({"action":"opened"})
    signature = "sha256=" <> hmac("secret", body)

    assert %{
             delivery_id: "delivery-1",
             event: "issues",
             signature: ^signature
           } =
             Webhook.parse_headers(%{
               "x-github-delivery" => "delivery-1",
               "x-github-event" => "issues",
               "x-hub-signature-256" => signature
             })

    assert {:ok, %{delivery_id: "delivery-1", event: "issues", payload: %{"action" => "opened"}}} =
             Webhook.verify_request(
               body,
               %{
                 "x-github-delivery" => "delivery-1",
                 "x-github-event" => "issues",
                 "x-hub-signature-256" => signature
               },
               "secret"
             )

    assert {:ok,
            %WebhookDelivery{
              provider: :github,
              delivery_id: "delivery-1",
              event: "issues",
              signature_state: :verified,
              duplicate?: true,
              payload: %{"action" => "opened"}
            }} =
             Webhook.verify_delivery(
               body,
               %{
                 "x-github-delivery" => "delivery-1",
                 "x-github-event" => "issues",
                 "x-hub-signature-256" => signature
               },
               "secret",
               seen_delivery_ids: ["delivery-1"]
             )
  end

  test "rejects missing and invalid signatures" do
    assert {:error, %Error.AuthError{reason: :missing_secret}} =
             Webhook.verify_signature("{}", "sha256=anything", nil)

    assert {:error, %Error.AuthError{reason: :missing_secret}} =
             Webhook.verify_signature("{}", "sha256=anything", "")

    assert {:error, %Error.AuthError{reason: :missing_signature}} =
             Webhook.verify_signature("{}", nil, "secret")

    assert {:error, %Error.AuthError{reason: :invalid_signature}} =
             Webhook.verify_signature("{}", "sha256=bad", "secret")
  end

  test "normalizes GitHub issues event into poll signal shape" do
    payload = %{
      "action" => "opened",
      "repository" => %{"full_name" => "org/repo"},
      "issue" => %{
        "number" => 10,
        "title" => "Bug",
        "html_url" => "https://github.com/org/repo/issues/10"
      }
    }

    assert {:ok,
            %{
              repo: "org/repo",
              issue_number: 10,
              title: "Bug",
              url: "https://github.com/org/repo/issues/10"
            }} = Webhook.normalize_signal("issues", payload)

    assert {:ok, %{repo: "org/repo", issue_number: 10}} =
             Webhook.normalize_signal("issues", %{
               action: "opened",
               repository: %{"full_name" => "org/repo"},
               issue: %{"number" => 10, "title" => "Bug", "html_url" => "url"}
             })
  end

  test "does not normalize non-opened issue events into new issue signals" do
    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_issue_action,
              details: %{action: "closed"}
            }} =
             Webhook.normalize_signal("issues", %{"action" => "closed"})

    assert {:error, %Error.ProviderError{provider: :github, reason: :unsupported_event}} =
             Webhook.normalize_signal("push", %{})
  end

  test "invalid JSON payloads are provider errors" do
    body = "not json"
    signature = "sha256=" <> hmac("secret", body)

    assert {:error, %Error.ProviderError{provider: :github, reason: :invalid_payload}} =
             Webhook.verify_request(body, %{"x-hub-signature-256" => signature}, "secret")
  end

  test "detects duplicate delivery ids from host-provided seen set" do
    assert Webhook.duplicate?("delivery-1", ["delivery-1"])
    refute Webhook.duplicate?("delivery-2", ["delivery-1"])
  end

  defp hmac(secret, body) do
    :hmac
    |> :crypto.mac(:sha256, secret, body)
    |> Base.encode16(case: :lower)
  end
end
