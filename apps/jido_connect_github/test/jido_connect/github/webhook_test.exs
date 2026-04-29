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

  test "normalizes GitHub push event into stable signal shape" do
    payload = push_payload()

    assert {:ok,
            %{
              repository: %{
                id: 123,
                name: "repo",
                full_name: "org/repo",
                owner: %{login: "org"},
                private?: false,
                default_branch: "main",
                url: "https://github.com/org/repo"
              },
              ref: %{full: "refs/heads/main", name: "main", type: "branch"},
              before: "before-sha",
              after: "after-sha",
              compare_url: "https://github.com/org/repo/compare/before...after",
              commits: [
                %{
                  id: "after-sha",
                  distinct?: true,
                  message: "Ship it",
                  timestamp: "2026-04-29T15:00:00Z",
                  url: "https://github.com/org/repo/commit/after-sha",
                  author: %{name: "A Dev", email: "a@example.com", username: "adev"},
                  committer: %{name: "C Dev", email: "c@example.com", username: "cdev"},
                  added: ["lib/new.ex"],
                  removed: [],
                  modified: ["README.md"]
                }
              ],
              head_commit: %{id: "after-sha", message: "Ship it"},
              pusher: %{name: "A Dev", email: "a@example.com"},
              created?: false,
              deleted?: false,
              forced?: true
            }} = Webhook.normalize_signal("push", payload)
  end

  test "verified GitHub push deliveries include normalized signal delivery metadata" do
    body = Jason.encode!(push_payload())
    signature = "sha256=" <> hmac("secret", body)

    assert {:ok,
            %WebhookDelivery{
              provider: :github,
              delivery_id: "delivery-2",
              event: "push",
              duplicate?: true,
              normalized_signal: %{
                repository: %{full_name: "org/repo"},
                ref: %{name: "main", type: "branch"},
                commits: [%{id: "after-sha"}],
                pusher: %{email: "a@example.com"},
                delivery: %{
                  provider: :github,
                  event: "push",
                  id: "delivery-2",
                  duplicate?: true,
                  received_at: %DateTime{}
                }
              }
            }} =
             Webhook.verify_delivery(
               body,
               %{
                 "x-github-delivery" => "delivery-2",
                 "x-github-event" => "push",
                 "x-hub-signature-256" => signature
               },
               "secret",
               seen_delivery_ids: ["delivery-2"]
             )
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
             Webhook.normalize_signal("ping", %{})
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

  defp push_payload do
    %{
      "ref" => "refs/heads/main",
      "before" => "before-sha",
      "after" => "after-sha",
      "compare" => "https://github.com/org/repo/compare/before...after",
      "created" => false,
      "deleted" => false,
      "forced" => true,
      "repository" => %{
        "id" => 123,
        "node_id" => "repo-node",
        "name" => "repo",
        "full_name" => "org/repo",
        "private" => false,
        "default_branch" => "main",
        "html_url" => "https://github.com/org/repo",
        "owner" => %{"login" => "org", "id" => 456}
      },
      "pusher" => %{"name" => "A Dev", "email" => "a@example.com"},
      "commits" => [
        %{
          "id" => "after-sha",
          "tree_id" => "tree-sha",
          "distinct" => true,
          "message" => "Ship it",
          "timestamp" => "2026-04-29T15:00:00Z",
          "url" => "https://github.com/org/repo/commit/after-sha",
          "author" => %{
            "name" => "A Dev",
            "email" => "a@example.com",
            "username" => "adev"
          },
          "committer" => %{
            "name" => "C Dev",
            "email" => "c@example.com",
            "username" => "cdev"
          },
          "added" => ["lib/new.ex"],
          "removed" => [],
          "modified" => ["README.md"]
        }
      ],
      "head_commit" => %{"id" => "after-sha", "message" => "Ship it"}
    }
  end
end
