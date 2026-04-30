defmodule Jido.Connect.GitHub.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
  end

  test "list issues sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/issues"

      assert %{
               "direction" => "desc",
               "per_page" => "100",
               "sort" => "created",
               "state" => "open"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{number: 1, html_url: "https://github.test/1", title: "Issue", state: "open"}
      ])
    end)

    assert {:ok, [%{number: 1, url: "https://github.test/1"}]} =
             Client.list_issues("org/repo", "open", "token")
  end

  test "list repositories sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/installation/repositories"

      assert %{"page" => "2", "per_page" => "50"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        total_count: 1,
        repositories: [
          %{
            id: 10,
            name: "repo",
            full_name: "org/repo",
            private: true,
            default_branch: "main",
            html_url: "https://github.test/org/repo",
            owner: %{
              login: "org",
              id: 7,
              type: "Organization",
              html_url: "https://github.test/org"
            }
          }
        ]
      })
    end)

    assert {:ok,
            %{
              total_count: 1,
              repositories: [
                %{
                  id: 10,
                  full_name: "org/repo",
                  owner: %{login: "org"},
                  url: "https://github.test/org/repo"
                }
              ]
            }} =
             Client.list_repositories(
               %{auth_profile: :installation, page: 2, per_page: 50},
               "token"
             )
  end

  test "list repositories uses user endpoint for OAuth connections" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/user/repos"
      assert %{"page" => "1", "per_page" => "30"} = URI.decode_query(conn.query_string)

      Req.Test.json(conn, [
        %{
          id: 11,
          name: "repo",
          full_name: "octo/repo",
          private: false,
          default_branch: "main",
          html_url: "https://github.test/octo/repo",
          owner: %{login: "octo", id: 8, type: "User", html_url: "https://github.test/octo"}
        }
      ])
    end)

    assert {:ok,
            %{
              total_count: 1,
              repositories: [%{id: 11, full_name: "octo/repo", owner: %{login: "octo"}}]
            }} = Client.list_repositories(%{page: 1, per_page: 30}, "token")
  end

  test "get repository sends expected request and normalizes metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        id: 10,
        name: "repo",
        full_name: "org/repo",
        private: true,
        default_branch: "main",
        permissions: %{admin: false, push: true, pull: true},
        html_url: "https://github.test/org/repo",
        owner: %{
          login: "org",
          id: 7,
          type: "Organization",
          html_url: "https://github.test/org"
        }
      })
    end)

    assert {:ok,
            %{
              id: 10,
              name: "repo",
              full_name: "org/repo",
              permissions: %{"pull" => true},
              owner: %{login: "org"},
              url: "https://github.test/org/repo"
            }} = Client.get_repository("org", "repo", "token")
  end

  test "read file sends expected request and decodes UTF-8 content" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/contents/docs/Getting%20Started.md"
      assert %{"ref" => "feature/ref"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        type: "file",
        name: "Getting Started.md",
        path: "docs/Getting Started.md",
        sha: "abc123",
        size: 10,
        encoding: "base64",
        content: Base.encode64("hello\n"),
        url: "https://api.github.test/repos/org/repo/contents/docs/Getting%20Started.md",
        html_url: "https://github.test/org/repo/blob/main/docs/Getting%20Started.md",
        download_url: "https://raw.github.test/org/repo/main/docs/Getting%20Started.md"
      })
    end)

    assert {:ok,
            %{
              path: "docs/Getting Started.md",
              name: "Getting Started.md",
              sha: "abc123",
              size: 10,
              type: "file",
              encoding: "utf-8",
              binary: false,
              content: "hello\n",
              html_url: "https://github.test/org/repo/blob/main/docs/Getting%20Started.md"
            }} = Client.read_file("org/repo", "docs/Getting Started.md", "feature/ref", "token")
  end

  test "read file leaves binary payloads base64 encoded" do
    content_base64 = Base.encode64(<<0, 1, 2>>)

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/contents/image.png"
      assert "" == conn.query_string

      Req.Test.json(conn, %{
        type: "file",
        name: "image.png",
        path: "image.png",
        sha: "def456",
        size: 3,
        encoding: "base64",
        content: " #{content_base64}\n"
      })
    end)

    assert {:ok,
            %{
              path: "image.png",
              name: "image.png",
              encoding: "base64",
              binary: true,
              content_base64: ^content_base64
            } = file} = Client.read_file("org/repo", "image.png", nil, "token")

    refute Map.has_key?(file, :content)
  end

  test "update file sends expected request and normalizes content and commit" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/repos/org/repo/contents/docs/Getting%20Started.md"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "content" => Base.encode64("hello\n"),
               "message" => "Update docs",
               "branch" => "main",
               "sha" => "abc123",
               "committer" => %{"name" => "Octo Cat", "email" => "octo@example.com"}
             }

      Req.Test.json(conn, %{
        content: %{
          sha: "def456",
          url: "https://api.github.test/repos/org/repo/contents/docs/Getting%20Started.md",
          html_url: "https://github.test/org/repo/blob/main/docs/Getting%20Started.md",
          download_url: "https://raw.github.test/org/repo/main/docs/Getting%20Started.md"
        },
        commit: %{
          sha: "commit123",
          message: "Update docs"
        }
      })
    end)

    assert {:ok,
            %{
              sha: "def456",
              url: "https://api.github.test/repos/org/repo/contents/docs/Getting%20Started.md",
              html_url: "https://github.test/org/repo/blob/main/docs/Getting%20Started.md",
              download_url: "https://raw.github.test/org/repo/main/docs/Getting%20Started.md",
              commit_sha: "commit123",
              commit_message: "Update docs"
            }} =
             Client.update_file(
               "org/repo",
               "docs/Getting Started.md",
               %{
                 content: "hello\n",
                 message: "Update docs",
                 branch: "main",
                 sha: "abc123",
                 committer: %{name: "Octo Cat", email: "octo@example.com"}
               },
               "token"
             )
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

  test "list workflow runs sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/actions/workflows/ci.yml/runs"

      assert %{
               "branch" => "main",
               "event" => "push",
               "page" => "2",
               "per_page" => "10",
               "status" => "completed"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        total_count: 1,
        workflow_runs: [
          %{
            id: 22,
            name: "CI",
            run_number: 17,
            status: "completed",
            conclusion: "success",
            event: "push",
            head_branch: "main",
            head_sha: "abc123",
            workflow_id: 9001,
            html_url: "https://github.test/runs/22",
            created_at: "2026-04-29T10:00:00Z",
            updated_at: "2026-04-29T10:05:00Z"
          }
        ]
      })
    end)

    assert {:ok,
            %{
              total_count: 1,
              workflow_runs: [
                %{
                  id: 22,
                  name: "CI",
                  number: 17,
                  status: "completed",
                  conclusion: "success",
                  event: "push",
                  branch: "main",
                  sha: "abc123",
                  workflow_id: 9001,
                  url: "https://github.test/runs/22"
                }
              ]
            }} =
             Client.list_workflow_runs(
               %{
                 repo: "org/repo",
                 workflow: "ci.yml",
                 branch: "main",
                 status: "completed",
                 event: "push",
                 page: 2,
                 per_page: 10
               },
               "token"
             )
  end

  test "list releases sends expected requests and normalizes releases and tags" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert %{"page" => "2", "per_page" => "10"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      case conn.request_path do
        "/repos/org/repo/releases" ->
          Req.Test.json(conn, [
            %{
              id: 101,
              tag_name: "v1.0.0",
              name: "v1.0.0",
              draft: false,
              prerelease: false,
              target_commitish: "main",
              author: %{login: "octocat", id: 1, type: "User"},
              html_url: "https://github.test/org/repo/releases/tag/v1.0.0",
              upload_url:
                "https://uploads.github.test/repos/org/repo/releases/101/assets{?name,label}",
              tarball_url: "https://api.github.test/repos/org/repo/tarball/v1.0.0",
              zipball_url: "https://api.github.test/repos/org/repo/zipball/v1.0.0",
              created_at: "2026-04-29T10:00:00Z",
              published_at: "2026-04-29T10:05:00Z",
              body: "Release notes"
            }
          ])

        "/repos/org/repo/tags" ->
          Req.Test.json(conn, [
            %{
              name: "v1.0.0",
              commit: %{
                sha: "abc123",
                url: "https://api.github.test/repos/org/repo/git/commits/abc123"
              }
            }
          ])
      end
    end)

    assert {:ok,
            %{
              releases: [
                %{
                  id: 101,
                  tag_name: "v1.0.0",
                  name: "v1.0.0",
                  draft: false,
                  prerelease: false,
                  target_commitish: "main",
                  author: %{login: "octocat"},
                  url: "https://github.test/org/repo/releases/tag/v1.0.0",
                  upload_url:
                    "https://uploads.github.test/repos/org/repo/releases/101/assets{?name,label}",
                  body: "Release notes"
                }
              ],
              tags: [
                %{
                  name: "v1.0.0",
                  sha: "abc123",
                  url: "https://api.github.test/repos/org/repo/git/commits/abc123"
                }
              ]
            }} =
             Client.list_releases(%{repo: "org/repo", page: 2, per_page: 10}, "token")
  end

  test "create release sends publication settings and normalizes release" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/releases"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")
      assert {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "tag_name" => "v1.0.0",
               "target_commitish" => "main",
               "name" => "v1.0.0",
               "body" => "Release notes",
               "draft" => true,
               "prerelease" => true,
               "generate_release_notes" => true,
               "make_latest" => "false"
             }

      Req.Test.json(conn, %{
        id: 102,
        tag_name: "v1.0.0",
        name: "v1.0.0",
        draft: true,
        prerelease: true,
        target_commitish: "main",
        author: %{login: "octocat", id: 1, type: "User"},
        html_url: "https://github.test/org/repo/releases/tag/v1.0.0",
        upload_url: "https://uploads.github.test/repos/org/repo/releases/102/assets{?name,label}",
        tarball_url: "https://api.github.test/repos/org/repo/tarball/v1.0.0",
        zipball_url: "https://api.github.test/repos/org/repo/zipball/v1.0.0",
        created_at: "2026-04-29T10:00:00Z",
        published_at: nil,
        body: "Release notes"
      })
    end)

    assert {:ok,
            %{
              id: 102,
              tag_name: "v1.0.0",
              name: "v1.0.0",
              draft: true,
              prerelease: true,
              target_commitish: "main",
              author: %{login: "octocat"},
              url: "https://github.test/org/repo/releases/tag/v1.0.0",
              upload_url:
                "https://uploads.github.test/repos/org/repo/releases/102/assets{?name,label}",
              body: "Release notes"
            }} =
             Client.create_release(
               "org/repo",
               %{
                 tag_name: "v1.0.0",
                 target_commitish: "main",
                 name: "v1.0.0",
                 body: "Release notes",
                 draft: true,
                 prerelease: true,
                 generate_release_notes: true,
                 make_latest: "false"
               },
               "token"
             )
  end

  test "upload release asset posts bytes to upload URL and normalizes asset metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.host == "uploads.github.test"
      assert conn.request_path == "/repos/org/repo/releases/102/assets"

      assert %{"name" => "dist.zip", "label" => "Distribution"} =
               URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")
      assert ["application/zip"] = Plug.Conn.get_req_header(conn, "content-type")
      assert {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == "zip-bytes"

      Req.Test.json(conn, %{
        id: 201,
        node_id: "RA_kwDO",
        name: "dist.zip",
        label: "Distribution",
        state: "uploaded",
        content_type: "application/zip",
        size: 9,
        download_count: 0,
        url: "https://api.github.test/repos/org/repo/releases/assets/201",
        browser_download_url: "https://github.test/org/repo/releases/download/v1.0.0/dist.zip",
        created_at: "2026-04-29T10:10:00Z",
        updated_at: "2026-04-29T10:10:00Z",
        uploader: %{login: "octocat", id: 1, type: "User"}
      })
    end)

    assert {:ok,
            %{
              id: 201,
              name: "dist.zip",
              label: "Distribution",
              state: "uploaded",
              content_type: "application/zip",
              size: 9,
              download_count: 0,
              uploader: %{login: "octocat"}
            } = asset} =
             Client.upload_release_asset(
               "https://uploads.github.test/repos/org/repo/releases/102/assets{?name,label}",
               %{
                 name: "dist.zip",
                 label: "Distribution",
                 content_type: "application/zip",
                 content_base64: Base.encode64("zip-bytes")
               },
               "token"
             )

    refute Map.has_key?(asset, :content)
    refute Map.has_key?(asset, :content_base64)
  end

  test "upload release asset rejects invalid base64 content before posting" do
    Req.Test.stub(__MODULE__, fn conn ->
      flunk("unexpected request to #{conn.request_path}")
    end)

    assert {:error, %Error.ValidationError{reason: :invalid_content, subject: :content_base64}} =
             Client.upload_release_asset(
               "https://uploads.github.test/repos/org/repo/releases/102/assets{?name,label}",
               %{
                 name: "dist.zip",
                 content_type: "application/zip",
                 content_base64: "not base64"
               },
               "token"
             )
  end

  test "list workflow run jobs sends expected request and normalizes CI status" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/actions/runs/22/jobs"

      assert %{"filter" => "latest", "page" => "2", "per_page" => "10"} =
               URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        total_count: 2,
        jobs: [
          %{
            id: 33,
            run_id: 22,
            run_attempt: 1,
            name: "test",
            status: "completed",
            conclusion: "failure",
            html_url: "https://github.test/runs/22/job/33",
            started_at: "2026-04-29T10:00:00Z",
            completed_at: "2026-04-29T10:05:00Z",
            steps: [
              %{
                number: 1,
                name: "checkout",
                status: "completed",
                conclusion: "success",
                started_at: "2026-04-29T10:00:00Z",
                completed_at: "2026-04-29T10:01:00Z"
              },
              %{
                number: 2,
                name: "mix test",
                status: "completed",
                conclusion: "failure",
                started_at: "2026-04-29T10:01:00Z",
                completed_at: "2026-04-29T10:05:00Z"
              }
            ]
          },
          %{
            id: 34,
            run_id: 22,
            name: "deploy",
            status: "queued",
            conclusion: nil,
            steps: []
          }
        ]
      })
    end)

    assert {:ok,
            %{
              total_count: 2,
              ci_status: "failure",
              jobs: [
                %{
                  id: 33,
                  run_id: 22,
                  run_attempt: 1,
                  name: "test",
                  status: "completed",
                  conclusion: "failure",
                  ci_status: "failure",
                  url: "https://github.test/runs/22/job/33",
                  steps: [
                    %{number: 1, name: "checkout", ci_status: "success"},
                    %{number: 2, name: "mix test", ci_status: "failure"}
                  ]
                },
                %{id: 34, name: "deploy", status: "queued", ci_status: "queued", steps: []}
              ]
            }} =
             Client.list_workflow_run_jobs(
               %{repo: "org/repo", run_id: 22, filter: "latest", page: 2, per_page: 10},
               "token"
             )
  end

  test "rerun workflow run sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/actions/runs/22/rerun"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Plug.Conn.send_resp(conn, 201, "")
    end)

    assert {:ok, %{rerun_requested: true}} =
             Client.rerun_workflow_run("org/repo", 22, %{failed_only: false}, "token")
  end

  test "rerun workflow run can target failed jobs only" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/actions/runs/22/rerun-failed-jobs"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Plug.Conn.send_resp(conn, 201, "")
    end)

    assert {:ok, %{rerun_requested: true}} =
             Client.rerun_workflow_run("org/repo", 22, %{failed_only: true}, "token")
  end

  test "cancel workflow run sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/actions/runs/22/cancel"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Plug.Conn.send_resp(conn, 202, "")
    end)

    assert {:ok, %{cancel_requested: true}} =
             Client.cancel_workflow_run("org/repo", 22, "token")
  end

  test "dispatch workflow sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/actions/workflows/ci.yml/dispatches"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")
      assert {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "ref" => "main",
               "inputs" => %{"environment" => "staging", "deploy" => true}
             }

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{dispatched: true}} =
             Client.dispatch_workflow(
               "org/repo",
               "ci.yml",
               %{ref: "main", inputs: %{"environment" => "staging", "deploy" => true}},
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

  test "create issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues"

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "open"
      })
    end)

    assert {:ok, %{number: 2, title: "Bug"}} =
             Client.create_issue("org/repo", %{title: "Bug"}, "token")
  end

  test "update issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/org/repo/issues/2"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "assignees" => ["octocat"],
               "labels" => ["bug"],
               "milestone" => 3,
               "state" => "open",
               "title" => "Bug"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "open"
      })
    end)

    assert {:ok, %{number: 2, title: "Bug"}} =
             Client.update_issue(
               "org/repo",
               2,
               %{
                 title: "Bug",
                 state: "open",
                 labels: ["bug"],
                 milestone: 3,
                 assignees: ["octocat"]
               },
               "token"
             )
  end

  test "add issue labels sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues/2/labels"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"labels" => ["bug", "triage"]} = Jason.decode!(body)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          name: "bug",
          color: "d73a4a",
          description: "Something is not working"
        },
        %{
          name: "triage",
          color: "ededed",
          description: nil
        }
      ])
    end)

    assert {:ok,
            [
              %{name: "bug", color: "d73a4a", description: "Something is not working"},
              %{name: "triage", color: "ededed"}
            ]} = Client.add_issue_labels("org/repo", 2, ["bug", "triage"], "token")
  end

  test "assign issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues/2/assignees"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"assignees" => ["octocat", "mona"]} = Jason.decode!(body)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "open",
        assignees: [
          %{login: "octocat", id: 1, type: "User", html_url: "https://github.test/octocat"},
          %{login: "mona", id: 2, type: "User", html_url: "https://github.test/mona"}
        ]
      })
    end)

    assert {:ok,
            %{
              number: 2,
              title: "Bug",
              state: "open",
              assignees: [
                %{login: "octocat", id: 1, type: "User", url: "https://github.test/octocat"},
                %{login: "mona", id: 2, type: "User", url: "https://github.test/mona"}
              ]
            }} = Client.assign_issue("org/repo", 2, ["octocat", "mona"], "token")
  end

  test "create issue comment sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues/2/comments"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"body" => "Ship it"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        id: 3,
        html_url: "https://github.test/comments/3",
        body: "Ship it"
      })
    end)

    assert {:ok, %{id: 3, body: "Ship it"}} =
             Client.create_issue_comment("org/repo", 2, "Ship it", "token")
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

  test "list issue comments sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/issues/2/comments"

      assert %{
               "page" => "2",
               "per_page" => "10",
               "since" => "2026-04-29T10:00:00Z"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          id: 3,
          html_url: "https://github.test/comments/3",
          body: "Ship it",
          user: %{login: "octocat", id: 1, type: "User"},
          author_association: "MEMBER",
          created_at: "2026-04-29T10:01:00Z",
          updated_at: "2026-04-29T10:02:00Z"
        }
      ])
    end)

    assert {:ok,
            [
              %{
                id: 3,
                url: "https://github.test/comments/3",
                body: "Ship it",
                user: %{login: "octocat"},
                author_association: "MEMBER",
                created_at: "2026-04-29T10:01:00Z",
                updated_at: "2026-04-29T10:02:00Z"
              }
            ]} =
             Client.list_issue_comments(
               %{
                 repo: "org/repo",
                 issue_number: 2,
                 since: "2026-04-29T10:00:00Z",
                 page: 2,
                 per_page: 10
               },
               "token"
             )
  end

  test "close issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/org/repo/issues/2"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"state" => "closed", "state_reason" => "completed"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "closed"
      })
    end)

    assert {:ok, %{number: 2, state: "closed"}} = Client.close_issue("org/repo", 2, "token")
  end

  test "list new issues and fetch helpers use expected REST paths" do
    Req.Test.stub(__MODULE__, fn
      %{method: "GET", request_path: "/repos/org/repo/issues"} = conn ->
        assert %{"since" => "2026-04-24T20:00:00Z", "sort" => "updated"} =
                 URI.decode_query(conn.query_string)

        Req.Test.json(conn, [
          %{
            number: 3,
            html_url: "https://github.test/3",
            title: "Third",
            state: "open",
            updated_at: "2026-04-24T21:00:00Z"
          }
        ])

      %{method: "GET", request_path: "/user"} = conn ->
        Req.Test.json(conn, %{login: "octocat"})

      %{method: "GET", request_path: "/app/installations/42"} = conn ->
        Req.Test.json(conn, %{id: 42})
    end)

    assert {:ok, [%{number: 3, updated_at: "2026-04-24T21:00:00Z"}]} =
             Client.list_new_issues("org/repo", "2026-04-24T20:00:00Z", "token")

    assert {:ok, %{"login" => "octocat"}} = Client.fetch_authenticated_user("token")
    assert {:ok, %{"id" => 42}} = Client.fetch_installation(42, "token")
  end

  test "normalizes error responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{message: "Resource not accessible"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :http_error,
              status: 403,
              details: %{message: "Resource not accessible"}
            }} =
             Client.fetch_authenticated_user("token")
  end

  test "normalizes list and issue mutation error responses" do
    Req.Test.stub(__MODULE__, fn
      %{method: "GET"} = conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{message: "Not Found"})

      %{method: "POST"} = conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{message: "Validation Failed"})

      %{method: "PATCH"} = conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{message: "Validation Failed"})
    end)

    assert {:error, %Error.ProviderError{status: 404, details: %{message: "Not Found"}}} =
             Client.list_issues("org/missing", "open", "token")

    assert {:error, %Error.ProviderError{status: 404, details: %{message: "Not Found"}}} =
             Client.get_repository("org", "missing", "token")

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.create_issue("org/repo", %{title: ""}, "token")

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.update_issue("org/repo", 2, %{title: ""}, "token")

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.update_pull_request("org/repo", 5, %{title: ""}, "token")
  end

  test "normalizes issue comment mutation error responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{message: "Validation Failed"})
    end)

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.create_issue_comment("org/repo", 2, "", "token")
  end

  test "normalizes malformed successful responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{unexpected: true})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :invalid_response,
              details: %{body: %{"unexpected" => true}}
            }} = Client.list_issues("org/repo", "open", "token")
  end

  test "normalizes malformed repository list responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{unexpected: true})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :invalid_response,
              details: %{body: %{"unexpected" => true}}
            }} =
             Client.list_repositories(
               %{auth_profile: :installation, page: 1, per_page: 30},
               "token"
             )
  end

  test "normalizes malformed repository get responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["unexpected"])
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :invalid_response,
              details: %{body: ["unexpected"]}
            }} = Client.get_repository("org", "repo", "token")
  end
end
