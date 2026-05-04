defmodule Jido.Connect.GitHub.Client.ReleasesTest do
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
end
