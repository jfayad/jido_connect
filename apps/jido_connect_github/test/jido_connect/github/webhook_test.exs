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

  test "normalizes GitHub pull request lifecycle actions" do
    assert {:ok,
            %{
              action: "opened",
              github_action: "opened",
              repo: "org/repo",
              pull_request_number: 42,
              title: "Add webhook support",
              url: "https://github.com/org/repo/pull/42",
              state: "open",
              draft?: false,
              merged?: false,
              repository: %{full_name: "org/repo"},
              pull_request: %{
                number: 42,
                title: "Add webhook support",
                state: "open",
                draft?: false,
                merged?: false,
                head: %{ref: "feature/webhooks", sha: "head-sha", repo: %{full_name: "org/repo"}},
                base: %{ref: "main", sha: "base-sha", repo: %{full_name: "org/repo"}}
              },
              sender: %{login: "sender"}
            }} = Webhook.normalize_signal("pull_request", pull_request_payload("opened"))

    assert {:ok, %{action: "synchronize", pull_request: %{head: %{sha: "new-head-sha"}}}} =
             Webhook.normalize_signal(
               "pull_request",
               pull_request_payload("synchronize", %{
                 "pull_request" => %{"head" => %{"sha" => "new-head-sha"}}
               })
             )

    assert {:ok, %{action: "synchronized", github_action: "synchronized"}} =
             Webhook.normalize_signal("pull_request", pull_request_payload("synchronized"))

    assert {:ok, %{action: "reopened", state: "open"}} =
             Webhook.normalize_signal("pull_request", pull_request_payload("reopened"))

    assert {:ok, %{action: "closed", state: "closed", merged?: false}} =
             Webhook.normalize_signal("pull_request", pull_request_payload("closed"))

    assert {:ok,
            %{
              action: "merged",
              github_action: "closed",
              state: "closed",
              merged?: true,
              pull_request: %{merged?: true, merged_at: "2026-04-29T15:10:00Z"}
            }} =
             Webhook.normalize_signal(
               "pull_request",
               pull_request_payload("closed", %{
                 "pull_request" => %{
                   "merged" => true,
                   "merged_at" => "2026-04-29T15:10:00Z"
                 }
               })
             )

    assert {:ok, %{action: "ready_for_review", draft?: false}} =
             Webhook.normalize_signal("pull_request", pull_request_payload("ready_for_review"))

    assert {:ok, %{action: "converted_to_draft", draft?: true, pull_request: %{draft?: true}}} =
             Webhook.normalize_signal(
               "pull_request",
               pull_request_payload("converted_to_draft", %{"pull_request" => %{"draft" => true}})
             )
  end

  test "normalizes GitHub pull request edits with changes" do
    assert {:ok,
            %{
              action: "synchronize",
              changes: %{"base" => %{from: %{"ref" => "develop"}}}
            }} =
             Webhook.normalize_signal(
               "pull_request",
               pull_request_payload("synchronize", %{
                 "changes" => %{"base" => %{"from" => %{"ref" => "develop"}}}
               })
             )
  end

  test "normalizes GitHub pull request review actions" do
    assert {:ok,
            %{
              action: "submitted",
              repo: "org/repo",
              pull_request_number: 42,
              review_id: 1001,
              review_state: "approved",
              title: "Add webhook support",
              url: "https://github.com/org/repo/pull/42#pullrequestreview-1001",
              repository: %{full_name: "org/repo"},
              pull_request: %{number: 42, title: "Add webhook support"},
              review: %{
                id: 1001,
                body: "Looks good",
                state: "approved",
                commit_id: "head-sha",
                submitted_at: "2026-04-29T15:02:00Z",
                url: "https://github.com/org/repo/pull/42#pullrequestreview-1001",
                pull_request_url: "https://api.github.com/repos/org/repo/pulls/42",
                author: %{login: "reviewer"}
              },
              sender: %{login: "sender"}
            }} =
             Webhook.normalize_signal(
               "pull_request_review",
               pull_request_review_payload("submitted")
             )

    assert {:ok,
            %{
              action: "edited",
              changes: %{"body" => %{from: "Old review"}},
              review: %{body: "Updated review"}
            }} =
             Webhook.normalize_signal(
               "pull_request_review",
               pull_request_review_payload("edited", %{
                 "review" => %{"body" => "Updated review"},
                 "changes" => %{"body" => %{"from" => "Old review"}}
               })
             )

    assert {:ok, %{action: "dismissed", review: %{state: "dismissed"}}} =
             Webhook.normalize_signal(
               "pull_request_review",
               pull_request_review_payload("dismissed", %{"review" => %{"state" => "dismissed"}})
             )
  end

  test "normalizes GitHub pull request review comment actions" do
    assert {:ok,
            %{
              action: "created",
              repo: "org/repo",
              pull_request_number: 42,
              comment_id: 2002,
              title: "Add webhook support",
              url: "https://github.com/org/repo/pull/42#discussion_r2002",
              repository: %{full_name: "org/repo"},
              pull_request: %{number: 42, title: "Add webhook support"},
              comment: %{
                id: 2002,
                body: "Please rename this",
                path: "lib/example.ex",
                line: 12,
                side: "RIGHT",
                commit_id: "head-sha",
                pull_request_review_id: 1001,
                url: "https://github.com/org/repo/pull/42#discussion_r2002",
                pull_request_url: "https://api.github.com/repos/org/repo/pulls/42",
                author: %{login: "reviewer"}
              },
              sender: %{login: "sender"}
            }} =
             Webhook.normalize_signal(
               "pull_request_review_comment",
               pull_request_review_comment_payload("created")
             )

    assert {:ok,
            %{
              action: "edited",
              changes: %{"body" => %{from: "Old comment"}},
              comment: %{body: "Updated comment"}
            }} =
             Webhook.normalize_signal(
               "pull_request_review_comment",
               pull_request_review_comment_payload("edited", %{
                 "comment" => %{"body" => "Updated comment"},
                 "changes" => %{"body" => %{"from" => "Old comment"}}
               })
             )

    assert {:ok, %{action: "deleted", comment: %{id: 2002}}} =
             Webhook.normalize_signal(
               "pull_request_review_comment",
               pull_request_review_comment_payload("deleted")
             )
  end

  test "normalizes GitHub release lifecycle actions" do
    assert {:ok,
            %{
              action: "published",
              repo: "org/repo",
              release_id: 3003,
              tag_name: "v1.2.3",
              name: "Version 1.2.3",
              url: "https://github.com/org/repo/releases/tag/v1.2.3",
              draft?: false,
              prerelease?: false,
              target_commitish: "main",
              published_at: "2026-04-29T15:10:00Z",
              repository: %{full_name: "org/repo"},
              release: %{
                id: 3003,
                tag_name: "v1.2.3",
                name: "Version 1.2.3",
                body: "Release notes",
                draft?: false,
                prerelease?: false,
                target_commitish: "main",
                url: "https://github.com/org/repo/releases/tag/v1.2.3",
                api_url: "https://api.github.com/repos/org/repo/releases/3003",
                upload_url:
                  "https://uploads.github.com/repos/org/repo/releases/3003/assets{?name,label}",
                tarball_url: "https://api.github.com/repos/org/repo/tarball/v1.2.3",
                zipball_url: "https://api.github.com/repos/org/repo/zipball/v1.2.3",
                created_at: "2026-04-29T15:00:00Z",
                published_at: "2026-04-29T15:10:00Z",
                author: %{login: "author"}
              },
              sender: %{login: "sender"}
            }} = Webhook.normalize_signal("release", release_payload("published"))

    assert {:ok,
            %{
              action: "edited",
              changes: %{"name" => %{from: "Old release name"}},
              release: %{name: "Version 1.2.3"}
            }} =
             Webhook.normalize_signal(
               "release",
               release_payload("edited", %{
                 "changes" => %{"name" => %{"from" => "Old release name"}}
               })
             )

    for action <- ["unpublished", "deleted", "prereleased", "released"] do
      assert {:ok, %{action: ^action, release: %{tag_name: "v1.2.3"}}} =
               Webhook.normalize_signal("release", release_payload(action))
    end
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

  test "normalizes GitHub workflow run lifecycle actions" do
    assert {:ok,
            %{
              action: "requested",
              repo: "org/repo",
              workflow_run_id: 22,
              workflow_run_number: 17,
              workflow_name: "CI",
              status: "requested",
              ci_status: "queued",
              failure?: false,
              branch: "main",
              sha: "head-sha",
              workflow_id: 9001,
              run_attempt: 1,
              run_started_at: "2026-04-29T15:00:00Z",
              url: "https://github.com/org/repo/actions/runs/22",
              repository: %{full_name: "org/repo"},
              workflow_run: %{
                id: 22,
                name: "CI",
                number: 17,
                status: "requested",
                ci_status: "queued",
                event: "push",
                branch: "main",
                sha: "head-sha",
                actor: %{login: "author"},
                triggering_actor: %{login: "sender"},
                head_commit: %{id: "head-sha", message: "Run CI"}
              },
              sender: %{login: "sender"}
            }} = Webhook.normalize_signal("workflow_run", workflow_run_payload("requested"))

    assert {:ok, %{action: "in_progress", status: "in_progress", ci_status: "in_progress"}} =
             Webhook.normalize_signal("workflow_run", workflow_run_payload("in_progress"))

    assert {:ok,
            %{
              action: "completed",
              status: "completed",
              conclusion: "success",
              ci_status: "success",
              failure?: false
            }} =
             Webhook.normalize_signal(
               "workflow_run",
               workflow_run_payload("completed", %{"workflow_run" => %{"conclusion" => "success"}})
             )
  end

  test "normalizes GitHub workflow run failure-oriented metadata" do
    for conclusion <- ["failure", "startup_failure", "timed_out", "action_required", "cancelled"] do
      assert {:ok,
              %{
                action: "completed",
                status: "completed",
                conclusion: ^conclusion,
                ci_status: ^conclusion,
                failure?: true,
                failure_kind: ^conclusion,
                workflow_run: %{ci_status: ^conclusion}
              }} =
               Webhook.normalize_signal(
                 "workflow_run",
                 workflow_run_payload("completed", %{
                   "workflow_run" => %{"conclusion" => conclusion}
                 })
               )
    end
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

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_pull_request_action,
              details: %{action: "auto_merge_enabled"}
            }} =
             Webhook.normalize_signal("pull_request", %{"action" => "auto_merge_enabled"})

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_pull_request_review_action,
              details: %{action: "created"}
            }} =
             Webhook.normalize_signal("pull_request_review", %{"action" => "created"})

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_pull_request_review_comment_action,
              details: %{action: "resolved"}
            }} =
             Webhook.normalize_signal("pull_request_review_comment", %{"action" => "resolved"})

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_release_action,
              details: %{action: "created"}
            }} =
             Webhook.normalize_signal("release", %{"action" => "created"})

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :unsupported_workflow_run_action,
              details: %{action: "rerequested"}
            }} =
             Webhook.normalize_signal("workflow_run", %{"action" => "rerequested"})

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

  defp pull_request_payload(action, extra \\ %{}) do
    Map.merge(
      %{
        "action" => action,
        "repository" => github_repository(),
        "pull_request" => %{
          "id" => 789,
          "node_id" => "pr-node",
          "number" => 42,
          "title" => "Add webhook support",
          "body" => "Details",
          "state" => pull_request_state(action),
          "draft" => false,
          "merged" => false,
          "html_url" => "https://github.com/org/repo/pull/42",
          "url" => "https://api.github.com/repos/org/repo/pulls/42",
          "diff_url" => "https://github.com/org/repo/pull/42.diff",
          "patch_url" => "https://github.com/org/repo/pull/42.patch",
          "created_at" => "2026-04-29T15:00:00Z",
          "updated_at" => "2026-04-29T15:01:00Z",
          "closed_at" => pull_request_closed_at(action),
          "user" => %{"login" => "author"},
          "labels" => [%{"name" => "enhancement"}],
          "assignees" => [%{"login" => "reviewer"}],
          "head" => %{
            "label" => "org:feature/webhooks",
            "ref" => "feature/webhooks",
            "sha" => "head-sha",
            "user" => %{"login" => "author"},
            "repo" => github_repository()
          },
          "base" => %{
            "label" => "org:main",
            "ref" => "main",
            "sha" => "base-sha",
            "user" => %{"login" => "org"},
            "repo" => github_repository()
          }
        },
        "sender" => %{"login" => "sender"}
      },
      extra,
      fn _key, original, override ->
        if is_map(original) and is_map(override),
          do: deep_merge(original, override),
          else: override
      end
    )
  end

  defp pull_request_state("closed"), do: "closed"
  defp pull_request_state(_action), do: "open"

  defp pull_request_closed_at("closed"), do: "2026-04-29T15:05:00Z"
  defp pull_request_closed_at(_action), do: nil

  defp pull_request_review_payload(action, extra \\ %{}) do
    Map.merge(
      pull_request_payload(action),
      %{
        "action" => action,
        "review" => %{
          "id" => 1001,
          "node_id" => "review-node",
          "body" => "Looks good",
          "state" => "approved",
          "commit_id" => "head-sha",
          "html_url" => "https://github.com/org/repo/pull/42#pullrequestreview-1001",
          "url" => "https://api.github.com/repos/org/repo/pulls/42/reviews/1001",
          "pull_request_url" => "https://api.github.com/repos/org/repo/pulls/42",
          "submitted_at" => "2026-04-29T15:02:00Z",
          "user" => %{"login" => "reviewer"}
        }
      }
    )
    |> deep_merge(extra)
  end

  defp pull_request_review_comment_payload(action, extra \\ %{}) do
    Map.merge(
      pull_request_payload(action),
      %{
        "action" => action,
        "comment" => %{
          "id" => 2002,
          "node_id" => "review-comment-node",
          "body" => "Please rename this",
          "diff_hunk" => "@@ -10,7 +10,7 @@",
          "path" => "lib/example.ex",
          "position" => 3,
          "original_position" => 3,
          "line" => 12,
          "original_line" => 12,
          "side" => "RIGHT",
          "commit_id" => "head-sha",
          "original_commit_id" => "head-sha",
          "pull_request_review_id" => 1001,
          "html_url" => "https://github.com/org/repo/pull/42#discussion_r2002",
          "url" => "https://api.github.com/repos/org/repo/pulls/comments/2002",
          "pull_request_url" => "https://api.github.com/repos/org/repo/pulls/42",
          "created_at" => "2026-04-29T15:03:00Z",
          "updated_at" => "2026-04-29T15:04:00Z",
          "user" => %{"login" => "reviewer"}
        }
      }
    )
    |> deep_merge(extra)
  end

  defp release_payload(action, extra \\ %{}) do
    Map.merge(
      %{
        "action" => action,
        "repository" => github_repository(),
        "release" => %{
          "id" => 3003,
          "node_id" => "release-node",
          "tag_name" => "v1.2.3",
          "name" => "Version 1.2.3",
          "body" => "Release notes",
          "draft" => false,
          "prerelease" => false,
          "target_commitish" => "main",
          "html_url" => "https://github.com/org/repo/releases/tag/v1.2.3",
          "url" => "https://api.github.com/repos/org/repo/releases/3003",
          "upload_url" =>
            "https://uploads.github.com/repos/org/repo/releases/3003/assets{?name,label}",
          "tarball_url" => "https://api.github.com/repos/org/repo/tarball/v1.2.3",
          "zipball_url" => "https://api.github.com/repos/org/repo/zipball/v1.2.3",
          "created_at" => "2026-04-29T15:00:00Z",
          "published_at" => "2026-04-29T15:10:00Z",
          "author" => %{"login" => "author"}
        },
        "sender" => %{"login" => "sender"}
      },
      extra,
      fn _key, original, override ->
        if is_map(original) and is_map(override),
          do: deep_merge(original, override),
          else: override
      end
    )
  end

  defp github_repository do
    %{
      "id" => 123,
      "node_id" => "repo-node",
      "name" => "repo",
      "full_name" => "org/repo",
      "private" => false,
      "default_branch" => "main",
      "html_url" => "https://github.com/org/repo",
      "owner" => %{"login" => "org", "id" => 456}
    }
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      if is_map(left_value) and is_map(right_value),
        do: deep_merge(left_value, right_value),
        else: right_value
    end)
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

  defp workflow_run_payload(action, extra \\ %{}) do
    Map.merge(
      %{
        "action" => action,
        "repository" => github_repository(),
        "workflow_run" => %{
          "id" => 22,
          "node_id" => "workflow-run-node",
          "name" => "CI",
          "run_number" => 17,
          "run_attempt" => 1,
          "status" => workflow_run_status(action),
          "conclusion" => workflow_run_conclusion(action),
          "event" => "push",
          "head_branch" => "main",
          "head_sha" => "head-sha",
          "workflow_id" => 9001,
          "check_suite_id" => 3003,
          "check_suite_node_id" => "check-suite-node",
          "html_url" => "https://github.com/org/repo/actions/runs/22",
          "url" => "https://api.github.com/repos/org/repo/actions/runs/22",
          "jobs_url" => "https://api.github.com/repos/org/repo/actions/runs/22/jobs",
          "logs_url" => "https://api.github.com/repos/org/repo/actions/runs/22/logs",
          "created_at" => "2026-04-29T14:59:00Z",
          "updated_at" => "2026-04-29T15:01:00Z",
          "run_started_at" => "2026-04-29T15:00:00Z",
          "actor" => %{"login" => "author"},
          "triggering_actor" => %{"login" => "sender"},
          "head_commit" => %{"id" => "head-sha", "message" => "Run CI"}
        },
        "sender" => %{"login" => "sender"}
      },
      extra,
      fn _key, original, override ->
        if is_map(original) and is_map(override),
          do: deep_merge(original, override),
          else: override
      end
    )
  end

  defp workflow_run_status("requested"), do: "requested"
  defp workflow_run_status("in_progress"), do: "in_progress"
  defp workflow_run_status("completed"), do: "completed"

  defp workflow_run_conclusion("completed"), do: "failure"
  defp workflow_run_conclusion(_action), do: nil
end
