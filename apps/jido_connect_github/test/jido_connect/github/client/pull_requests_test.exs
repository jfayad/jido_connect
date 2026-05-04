defmodule Jido.Connect.GitHub.Client.PullRequestsTest do
  use ExUnit.Case, async: false
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
  end

  test "list pull requests sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/pulls"

      assert %{
               "base" => "main",
               "direction" => "asc",
               "head" => "octo:feature",
               "page" => "2",
               "per_page" => "10",
               "sort" => "updated",
               "state" => "open"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          number: 4,
          html_url: "https://github.test/pull/4",
          title: "Feature",
          state: "open",
          head: %{
            label: "octo:feature",
            ref: "feature",
            sha: "abc",
            repo: %{
              id: 10,
              name: "repo",
              full_name: "org/repo",
              html_url: "https://github.test/org/repo"
            }
          },
          base: %{label: "org:main", ref: "main", sha: "def"}
        }
      ])
    end)

    assert {:ok,
            [
              %{
                number: 4,
                url: "https://github.test/pull/4",
                head: %{ref: "feature", repo: %{full_name: "org/repo"}},
                base: %{ref: "main"}
              }
            ]} =
             Client.list_pull_requests(
               %{
                 repo: "org/repo",
                 state: "open",
                 head: "octo:feature",
                 base: "main",
                 sort: "updated",
                 direction: "asc",
                 page: 2,
                 per_page: 10
               },
               "token"
             )
  end

  test "list pull request files sends expected request and normalizes file stats" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/pulls/4/files"

      assert %{"page" => "2", "per_page" => "10"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          filename: "lib/example.ex",
          status: "modified",
          additions: 12,
          deletions: 3,
          changes: 15,
          sha: "abc123",
          blob_url: "https://github.test/org/repo/blob/abc123/lib/example.ex",
          raw_url: "https://github.test/org/repo/raw/abc123/lib/example.ex",
          contents_url: "https://api.github.test/repos/org/repo/contents/lib/example.ex",
          patch: "@@ -1 +1 @@"
        },
        %{
          filename: "lib/renamed.ex",
          previous_filename: "lib/old.ex",
          status: "renamed",
          additions: 4,
          deletions: 0,
          changes: 4,
          sha: "def456"
        }
      ])
    end)

    assert {:ok,
            [
              %{
                filename: "lib/example.ex",
                status: "modified",
                additions: 12,
                deletions: 3,
                changes: 15,
                sha: "abc123",
                patch: "@@ -1 +1 @@"
              },
              %{
                filename: "lib/renamed.ex",
                previous_filename: "lib/old.ex",
                status: "renamed",
                additions: 4,
                deletions: 0,
                changes: 4
              }
            ]} =
             Client.list_pull_request_files(
               %{repo: "org/repo", pull_number: 4, page: 2, per_page: 10},
               "token"
             )
  end

  test "search issues sends expected request and normalizes issues and pull requests" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/search/issues"

      assert %{
               "order" => "desc",
               "page" => "2",
               "per_page" => "10",
               "q" => "crash repo:org/repo is:pr state:open",
               "sort" => "updated"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        total_count: 2,
        items: [
          %{
            number: 5,
            html_url: "https://github.test/issues/5",
            title: "Crash",
            state: "open",
            user: %{login: "octocat", id: 1, type: "User"},
            labels: [%{name: "bug", color: "d73a4a"}],
            comments: 3,
            created_at: "2026-04-29T09:00:00Z",
            updated_at: "2026-04-29T10:00:00Z"
          },
          %{
            number: 6,
            html_url: "https://github.test/pull/6",
            title: "Fix crash",
            state: "open",
            pull_request: %{url: "https://api.github.test/pulls/6"},
            comments: 1
          }
        ]
      })
    end)

    assert {:ok,
            %{
              total_count: 2,
              results: [
                %{
                  type: :issue,
                  number: 5,
                  url: "https://github.test/issues/5",
                  user: %{login: "octocat"},
                  labels: [%{name: "bug"}],
                  comments: 3
                },
                %{
                  type: :pull_request,
                  number: 6,
                  url: "https://github.test/pull/6",
                  title: "Fix crash",
                  state: "open"
                }
              ]
            }} =
             Client.search_issues(
               %{
                 q: "crash repo:org/repo is:pr state:open",
                 sort: "updated",
                 direction: "desc",
                 page: 2,
                 per_page: 10
               },
               "token"
             )
  end

  test "get pull request sends expected requests" do
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(parent, {:request, conn.method, conn.request_path})

      case {conn.method, conn.request_path} do
        {"GET", "/repos/org/repo/pulls/4"} ->
          assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

          Req.Test.json(conn, %{
            number: 4,
            html_url: "https://github.test/pull/4",
            title: "Feature",
            state: "open",
            body: "Implements the feature",
            draft: false,
            merged: false,
            mergeable: true,
            mergeable_state: "clean",
            merge_commit_sha: "abc123",
            commits: 3,
            additions: 20,
            deletions: 5,
            changed_files: 2,
            head: %{label: "octo:feature", ref: "feature", sha: "abc"},
            base: %{label: "org:main", ref: "main", sha: "def"},
            user: %{
              login: "octocat",
              id: 1,
              type: "User",
              html_url: "https://github.test/octocat"
            },
            labels: [%{name: "enhancement", color: "84b6eb"}]
          })

        {"GET", "/repos/org/repo/issues/4"} ->
          assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

          Req.Test.json(conn, %{
            number: 4,
            html_url: "https://github.test/issues/4",
            title: "Feature",
            state: "open",
            labels: [%{name: "enhancement", color: "84b6eb"}],
            assignees: [
              %{login: "octocat", id: 1, type: "User", html_url: "https://github.test/octocat"}
            ],
            milestone: %{number: 1, title: "v1", state: "open"}
          })
      end
    end)

    assert {:ok,
            %{
              number: 4,
              url: "https://github.test/pull/4",
              mergeable: true,
              mergeable_state: "clean",
              head: %{ref: "feature"},
              base: %{ref: "main"},
              user: %{login: "octocat"},
              labels: [%{name: "enhancement"}],
              issue: %{
                number: 4,
                labels: [%{name: "enhancement"}],
                assignees: [%{login: "octocat"}],
                milestone: %{title: "v1"}
              }
            }} = Client.get_pull_request("org/repo", 4, "token")

    assert_received {:request, "GET", "/repos/org/repo/pulls/4"}
    assert_received {:request, "GET", "/repos/org/repo/issues/4"}
  end

  test "merge pull request sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/repos/org/repo/pulls/4/merge"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "commit_message" => "Ship the feature",
               "commit_title" => "Merge feature",
               "merge_method" => "squash",
               "sha" => "abc123"
             }

      Req.Test.json(conn, %{
        sha: "def456",
        merged: true,
        message: "Pull Request successfully merged"
      })
    end)

    assert {:ok, %{sha: "def456", merged: true, message: "Pull Request successfully merged"}} =
             Client.merge_pull_request(
               "org/repo",
               4,
               %{
                 merge_method: "squash",
                 commit_title: "Merge feature",
                 commit_message: "Ship the feature",
                 sha: "abc123"
               },
               "token"
             )
  end

  test "create pull request sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/pulls"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "base" => "main",
               "body" => "Implements the feature",
               "draft" => true,
               "head" => "octo:feature",
               "maintainer_can_modify" => false,
               "title" => "Feature"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        number: 5,
        html_url: "https://github.test/pull/5",
        title: "Feature",
        state: "open",
        body: "Implements the feature",
        draft: true,
        merged: false,
        mergeable: nil,
        mergeable_state: "unknown",
        maintainer_can_modify: false,
        head: %{label: "octo:feature", ref: "feature", sha: "abc"},
        base: %{label: "org:main", ref: "main", sha: "def"}
      })
    end)

    assert {:ok,
            %{
              number: 5,
              url: "https://github.test/pull/5",
              title: "Feature",
              draft: true,
              maintainer_can_modify: false,
              head: %{ref: "feature"},
              base: %{ref: "main"}
            }} =
             Client.create_pull_request(
               "org/repo",
               %{
                 title: "Feature",
                 body: "Implements the feature",
                 head: "octo:feature",
                 base: "main",
                 draft: true,
                 maintainer_can_modify: false
               },
               "token"
             )
  end

  test "update pull request sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/org/repo/pulls/5"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "base" => "release",
               "body" => "Updated body",
               "draft" => false,
               "maintainer_can_modify" => true,
               "state" => "open",
               "title" => "Updated feature"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        number: 5,
        html_url: "https://github.test/pull/5",
        title: "Updated feature",
        state: "open",
        body: "Updated body",
        draft: false,
        merged: false,
        mergeable: true,
        mergeable_state: "clean",
        maintainer_can_modify: true,
        head: %{label: "octo:feature", ref: "feature", sha: "abc"},
        base: %{label: "org:release", ref: "release", sha: "def"}
      })
    end)

    assert {:ok,
            %{
              number: 5,
              url: "https://github.test/pull/5",
              title: "Updated feature",
              draft: false,
              maintainer_can_modify: true,
              head: %{ref: "feature"},
              base: %{ref: "release"}
            }} =
             Client.update_pull_request(
               "org/repo",
               5,
               %{
                 title: "Updated feature",
                 body: "Updated body",
                 base: "release",
                 state: "open",
                 maintainer_can_modify: true,
                 draft: false
               },
               "token"
             )
  end

  test "request pull request reviewers sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/pulls/5/requested_reviewers"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "reviewers" => ["octocat"],
               "team_reviewers" => ["core"]
             }

      Req.Test.json(conn, %{
        number: 5,
        html_url: "https://github.test/pull/5",
        title: "Feature",
        state: "open",
        requested_reviewers: [
          %{login: "octocat", id: 1, type: "User", html_url: "https://github.test/octocat"}
        ],
        requested_teams: [
          %{
            id: 2,
            name: "Core",
            slug: "core",
            description: "Core maintainers",
            privacy: "closed",
            html_url: "https://github.test/orgs/org/teams/core"
          }
        ]
      })
    end)

    assert {:ok,
            %{
              number: 5,
              url: "https://github.test/pull/5",
              title: "Feature",
              state: "open",
              requested_reviewers: [
                %{login: "octocat", id: 1, type: "User", url: "https://github.test/octocat"}
              ],
              requested_teams: [
                %{
                  id: 2,
                  name: "Core",
                  slug: "core",
                  description: "Core maintainers",
                  privacy: "closed",
                  url: "https://github.test/orgs/org/teams/core"
                }
              ]
            }} =
             Client.request_pull_request_reviewers(
               "org/repo",
               5,
               %{reviewers: ["octocat"], team_reviewers: ["core"]},
               "token"
             )
  end

  test "create pull request review comment sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/pulls/5/comments"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "body" => "Consider extracting this helper",
               "commit_id" => "abc123",
               "path" => "lib/example.ex",
               "line" => 12,
               "side" => "RIGHT"
             }

      Req.Test.json(conn, %{
        id: 44,
        html_url: "https://github.test/pull/5#discussion-diff-44",
        body: "Consider extracting this helper",
        path: "lib/example.ex",
        commit_id: "abc123",
        diff_hunk: "@@ -10,6 +10,7 @@",
        line: 12,
        side: "RIGHT"
      })
    end)

    assert {:ok,
            %{
              id: 44,
              url: "https://github.test/pull/5#discussion-diff-44",
              body: "Consider extracting this helper",
              path: "lib/example.ex",
              commit_id: "abc123",
              diff_hunk: "@@ -10,6 +10,7 @@",
              line: 12,
              side: "RIGHT"
            }} =
             Client.create_pull_request_review_comment(
               "org/repo",
               5,
               %{
                 body: "Consider extracting this helper",
                 commit_id: "abc123",
                 path: "lib/example.ex",
                 line: 12,
                 side: "RIGHT"
               },
               "token"
             )
  end
end
