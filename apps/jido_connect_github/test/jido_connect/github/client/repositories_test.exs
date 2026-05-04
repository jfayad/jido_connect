defmodule Jido.Connect.GitHub.Client.RepositoriesTest do
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

  test "list branches sends expected request and normalizes branches" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/branches"
      assert %{"page" => "2", "per_page" => "50"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          name: "main",
          commit: %{
            sha: "abc123",
            url: "https://api.github.test/repos/org/repo/commits/abc123"
          },
          protected: true,
          protection_url: "https://api.github.test/repos/org/repo/branches/main/protection"
        }
      ])
    end)

    assert {:ok,
            [
              %{
                name: "main",
                sha: "abc123",
                commit: %{
                  sha: "abc123",
                  url: "https://api.github.test/repos/org/repo/commits/abc123"
                },
                protected: true,
                protection_url: "https://api.github.test/repos/org/repo/branches/main/protection"
              }
            ]} = Client.list_branches(%{repo: "org/repo", page: 2, per_page: 50}, "token")
  end

  test "create branch resolves source ref and posts git ref" do
    Req.Test.stub(__MODULE__, fn
      %{method: "GET", request_path: "/repos/org/repo/git/ref/heads/main"} = conn ->
        assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

        Req.Test.json(conn, %{
          ref: "refs/heads/main",
          object: %{
            sha: "abc123",
            type: "commit",
            url: "https://api.github.test/repos/org/repo/git/commits/abc123"
          }
        })

      %{method: "POST", request_path: "/repos/org/repo/git/refs"} = conn ->
        assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body) == %{
                 "ref" => "refs/heads/feature/example",
                 "sha" => "abc123"
               }

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{
          ref: "refs/heads/feature/example",
          url: "https://api.github.test/repos/org/repo/git/refs/heads/feature/example",
          object: %{
            sha: "abc123",
            type: "commit",
            url: "https://api.github.test/repos/org/repo/git/commits/abc123"
          }
        })
    end)

    assert {:ok,
            %{
              ref: "refs/heads/feature/example",
              sha: "abc123",
              url: "https://api.github.test/repos/org/repo/git/refs/heads/feature/example",
              object: %{sha: "abc123", type: "commit"}
            }} =
             Client.create_branch(
               "org/repo",
               %{branch: "feature/example", source_ref: "main"},
               "token"
             )
  end

  test "create branch posts source SHA without resolving ref" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/git/refs"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "ref" => "refs/heads/feature/example",
               "sha" => "abc123"
             }

      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(%{
        ref: "refs/heads/feature/example",
        object: %{sha: "abc123", type: "commit"}
      })
    end)

    assert {:ok, %{ref: "refs/heads/feature/example", sha: "abc123"}} =
             Client.create_branch(
               "org/repo",
               %{branch: "feature/example", source_sha: "abc123"},
               "token"
             )
  end

  test "create branch normalizes duplicate ref errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/git/refs"

      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{
        message: "Reference already exists",
        errors: [%{resource: "Reference", code: "already_exists"}]
      })
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :already_exists,
              status: 422,
              details: %{message: "Reference already exists"}
            }} =
             Client.create_branch(
               "org/repo",
               %{branch: "feature/example", source_sha: "abc123"},
               "token"
             )
  end

  test "list commits sends expected request and normalizes commits" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/commits"

      assert %{
               "page" => "2",
               "path" => "lib/example.ex",
               "per_page" => "50",
               "sha" => "main"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          sha: "abc123",
          html_url: "https://github.test/org/repo/commit/abc123",
          commit: %{
            message: "Add example",
            author: %{
              name: "Octo Cat",
              email: "octo@example.com",
              date: "2026-04-29T10:00:00Z"
            },
            committer: %{
              name: "Mona",
              email: "mona@example.com",
              date: "2026-04-29T10:05:00Z"
            }
          },
          author: %{
            login: "octocat",
            id: 1,
            type: "User",
            html_url: "https://github.test/octocat"
          },
          committer: %{
            login: "mona",
            id: 2,
            type: "User",
            html_url: "https://github.test/mona"
          },
          parents: [
            %{
              sha: "def456",
              html_url: "https://github.test/org/repo/commit/def456"
            }
          ]
        }
      ])
    end)

    assert {:ok,
            [
              %{
                sha: "abc123",
                url: "https://github.test/org/repo/commit/abc123",
                message: "Add example",
                author: %{
                  login: "octocat",
                  name: "Octo Cat",
                  email: "octo@example.com",
                  date: "2026-04-29T10:00:00Z"
                },
                committer: %{
                  login: "mona",
                  name: "Mona",
                  email: "mona@example.com",
                  date: "2026-04-29T10:05:00Z"
                },
                authored_at: "2026-04-29T10:00:00Z",
                committed_at: "2026-04-29T10:05:00Z",
                parents: [%{sha: "def456"}]
              }
            ]} =
             Client.list_commits(
               %{repo: "org/repo", ref: "main", path: "lib/example.ex", page: 2, per_page: 50},
               "token"
             )
  end

  test "compare refs sends expected request and normalizes status commits and files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/compare/main...feature%2Fref"

      assert %{"page" => "2", "per_page" => "50"} = URI.decode_query(conn.query_string)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        status: "ahead",
        ahead_by: 2,
        behind_by: 0,
        total_commits: 2,
        commits: [
          %{
            sha: "abc123",
            html_url: "https://github.test/org/repo/commit/abc123",
            commit: %{
              message: "Add example",
              author: %{
                name: "Octo Cat",
                email: "octo@example.com",
                date: "2026-04-29T10:00:00Z"
              },
              committer: %{
                name: "Mona",
                email: "mona@example.com",
                date: "2026-04-29T10:05:00Z"
              }
            },
            author: %{login: "octocat", id: 1, type: "User"},
            committer: %{login: "mona", id: 2, type: "User"},
            parents: [%{sha: "def456"}]
          }
        ],
        files: [
          %{
            filename: "lib/example.ex",
            status: "modified",
            additions: 12,
            deletions: 3,
            changes: 15,
            sha: "abc123",
            patch: "@@ -1 +1 @@"
          }
        ]
      })
    end)

    assert {:ok,
            %{
              status: "ahead",
              ahead_by: 2,
              behind_by: 0,
              total_commits: 2,
              commits: [
                %{
                  sha: "abc123",
                  message: "Add example",
                  author: %{login: "octocat", name: "Octo Cat"},
                  committer: %{login: "mona", name: "Mona"},
                  parents: [%{sha: "def456"}]
                }
              ],
              files: [
                %{
                  filename: "lib/example.ex",
                  status: "modified",
                  additions: 12,
                  deletions: 3,
                  changes: 15,
                  sha: "abc123",
                  patch: "@@ -1 +1 @@"
                }
              ]
            }} =
             Client.compare_refs(
               %{repo: "org/repo", base: "main", head: "feature/ref", page: 2, per_page: 50},
               "token"
             )
  end

  test "normalizes malformed repository list responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{unexpected: true})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["unexpected"]}}
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
              details: %{body_summary: %{type: :list, length: 1, sample_size: 1}}
            }} = Client.get_repository("org", "repo", "token")
  end
end
