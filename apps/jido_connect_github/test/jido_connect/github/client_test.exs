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
end
