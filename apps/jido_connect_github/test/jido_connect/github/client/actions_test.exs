defmodule Jido.Connect.GitHub.Client.ActionsTest do
  use ExUnit.Case, async: false
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
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
end
