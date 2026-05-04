defmodule Jido.Connect.GitHub.Client.ContentsTest do
  use ExUnit.Case, async: false
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
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
end
