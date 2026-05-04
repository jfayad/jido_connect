defmodule Jido.Connect.GitHub.Client.SearchTest do
  use ExUnit.Case, async: false
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
  end

  test "search repositories sends expected request and normalizes repository results" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/search/repositories"

      assert %{
               "order" => "desc",
               "page" => "2",
               "per_page" => "10",
               "q" => "jido org:acme language:elixir topic:agent archived:false fork:false",
               "sort" => "stars"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        total_count: 1,
        items: [
          %{
            id: 10,
            name: "repo",
            full_name: "acme/repo",
            private: false,
            default_branch: "main",
            html_url: "https://github.test/acme/repo",
            description: "Jido connector",
            language: "Elixir",
            stargazers_count: 42,
            forks_count: 7,
            open_issues_count: 3,
            archived: false,
            fork: false,
            updated_at: "2026-04-29T10:00:00Z",
            pushed_at: "2026-04-29T09:00:00Z",
            owner: %{
              login: "acme",
              id: 7,
              type: "Organization",
              html_url: "https://github.test/acme"
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
                  full_name: "acme/repo",
                  owner: %{login: "acme"},
                  url: "https://github.test/acme/repo",
                  language: "Elixir",
                  stargazers_count: 42,
                  forks_count: 7,
                  archived: false,
                  fork: false
                }
              ]
            }} =
             Client.search_repositories(
               %{
                 q: "jido org:acme language:elixir topic:agent archived:false fork:false",
                 sort: "stars",
                 direction: "desc",
                 page: 2,
                 per_page: 10
               },
               "token"
             )
  end
end
