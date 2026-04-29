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
              url: "https://github.com/org/repo/issues/10",
              action: "opened",
              repository: %{full_name: "org/repo"},
              issue: %{number: 10, title: "Bug", url: "https://github.com/org/repo/issues/10"}
            }} = Webhook.normalize_signal("issues", payload)

    assert {:ok, %{repo: "org/repo", issue_number: 10}} =
             Webhook.normalize_signal("issues", %{
               action: "opened",
               repository: %{"full_name" => "org/repo"},
               issue: %{"number" => 10, "title" => "Bug", "html_url" => "url"}
             })
  end

  test "normalizes GitHub issue lifecycle actions" do
    assert {:ok, %{action: "edited", changes: %{"title" => %{from: "Old title"}}}} =
             Webhook.normalize_signal(
               "issues",
               issue_payload("edited", %{
                 "changes" => %{"title" => %{"from" => "Old title"}}
               })
             )

    assert {:ok, %{action: "closed", issue: %{state: "closed", state_reason: "completed"}}} =
             Webhook.normalize_signal("issues", issue_payload("closed"))

    assert {:ok, %{action: "reopened", issue: %{state: "open"}}} =
             Webhook.normalize_signal("issues", issue_payload("reopened"))

    assert {:ok, %{action: "assigned", assignee: %{login: "octocat"}}} =
             Webhook.normalize_signal(
               "issues",
               issue_payload("assigned", %{
                 "assignee" => %{"login" => "octocat", "id" => 1}
               })
             )

    assert {:ok, %{action: "labeled", label: %{name: "bug", color: "d73a4a"}}} =
             Webhook.normalize_signal(
               "issues",
               issue_payload("labeled", %{
                 "label" => %{"name" => "bug", "color" => "d73a4a"}
               })
             )

    assert {:ok, %{action: "unlabeled", label: %{name: "bug", color: "d73a4a"}}} =
             Webhook.normalize_signal(
               "issues",
               issue_payload("unlabeled", %{
                 "label" => %{"name" => "bug", "color" => "d73a4a"}
               })
             )
  end

  test "normalizes GitHub issue comment actions" do
    assert {:ok,
            %{
              action: "created",
              repo: "org/repo",
              issue_number: 10,
              title: "Bug",
              url: "https://github.com/org/repo/issues/10#issuecomment-99",
              comment_id: 99,
              comment_target: "issue",
              pull_request?: false,
              repository: %{full_name: "org/repo"},
              issue: %{number: 10, pull_request?: false},
              comment: %{
                id: 99,
                body: "I can reproduce this",
                url: "https://github.com/org/repo/issues/10#issuecomment-99",
                issue_url: "https://api.github.com/repos/org/repo/issues/10",
                author: %{login: "commenter"}
              },
              sender: %{login: "sender"}
            }} = Webhook.normalize_signal("issue_comment", issue_comment_payload("created"))

    assert {:ok,
            %{
              action: "edited",
              changes: %{"body" => %{from: "Old comment"}},
              comment: %{body: "Updated comment"}
            }} =
             Webhook.normalize_signal(
               "issue_comment",
               issue_comment_payload("edited", %{
                 "comment" => %{"body" => "Updated comment"},
                 "changes" => %{"body" => %{"from" => "Old comment"}}
               })
             )

    assert {:ok, %{action: "deleted", comment: %{id: 99}}} =
             Webhook.normalize_signal("issue_comment", issue_comment_payload("deleted"))
  end

  test "distinguishes pull request issue comments" do
    payload =
      issue_comment_payload("created", %{
        "issue" => %{
          "number" => 11,
          "title" => "Fix crash",
          "html_url" => "https://github.com/org/repo/pull/11",
          "pull_request" => %{
            "url" => "https://api.github.com/repos/org/repo/pulls/11",
            "html_url" => "https://github.com/org/repo/pull/11",
            "diff_url" => "https://github.com/org/repo/pull/11.diff",
            "patch_url" => "https://github.com/org/repo/pull/11.patch"
          }
        },
        "comment" => %{
          "html_url" => "https://github.com/org/repo/pull/11#issuecomment-99"
        }
      })

    assert {:ok,
            %{
              issue_number: 11,
              comment_target: "pull_request",
              pull_request?: true,
              issue: %{
                pull_request?: true,
                pull_request: %{
                  url: "https://github.com/org/repo/pull/11",
                  api_url: "https://api.github.com/repos/org/repo/pulls/11"
                }
              },
              comment: %{url: "https://github.com/org/repo/pull/11#issuecomment-99"}
            }} = Webhook.normalize_signal("issue_comment", payload)
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

  test "does not normalize unsupported issue events" do
    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_issue_action,
              details: %{action: "transferred"}
            }} =
             Webhook.normalize_signal("issues", %{"action" => "transferred"})

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_issue_comment_action,
              details: %{action: "pinned"}
            }} =
             Webhook.normalize_signal("issue_comment", %{"action" => "pinned"})

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

  defp issue_payload(action, extra \\ %{}) do
    Map.merge(
      %{
        "action" => action,
        "repository" => %{
          "id" => 123,
          "name" => "repo",
          "full_name" => "org/repo",
          "html_url" => "https://github.com/org/repo",
          "owner" => %{"login" => "org"}
        },
        "issue" => %{
          "id" => 456,
          "number" => 10,
          "title" => "Bug",
          "body" => "Details",
          "state" => issue_state(action),
          "state_reason" => issue_state_reason(action),
          "html_url" => "https://github.com/org/repo/issues/10",
          "user" => %{"login" => "author"},
          "labels" => [%{"name" => "existing"}],
          "assignees" => [%{"login" => "assignee"}]
        },
        "sender" => %{"login" => "sender"}
      },
      extra
    )
  end

  defp issue_state("closed"), do: "closed"
  defp issue_state(_action), do: "open"

  defp issue_state_reason("closed"), do: "completed"
  defp issue_state_reason(_action), do: nil

  defp issue_comment_payload(action, extra \\ %{}) do
    Map.merge(
      %{
        "action" => action,
        "repository" => %{
          "id" => 123,
          "name" => "repo",
          "full_name" => "org/repo",
          "html_url" => "https://github.com/org/repo",
          "owner" => %{"login" => "org"}
        },
        "issue" => %{
          "id" => 456,
          "number" => 10,
          "title" => "Bug",
          "body" => "Details",
          "state" => "open",
          "html_url" => "https://github.com/org/repo/issues/10",
          "user" => %{"login" => "author"},
          "labels" => [%{"name" => "existing"}],
          "assignees" => [%{"login" => "assignee"}]
        },
        "comment" => %{
          "id" => 99,
          "node_id" => "comment-node",
          "body" => "I can reproduce this",
          "html_url" => "https://github.com/org/repo/issues/10#issuecomment-99",
          "url" => "https://api.github.com/repos/org/repo/issues/comments/99",
          "issue_url" => "https://api.github.com/repos/org/repo/issues/10",
          "created_at" => "2026-04-29T15:00:00Z",
          "updated_at" => "2026-04-29T15:01:00Z",
          "user" => %{"login" => "commenter"}
        },
        "sender" => %{"login" => "sender"}
      },
      extra,
      fn _key, original, override ->
        if is_map(original) and is_map(override),
          do: Map.merge(original, override),
          else: override
      end
    )
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
