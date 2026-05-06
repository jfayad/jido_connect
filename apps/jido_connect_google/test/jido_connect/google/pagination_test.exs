defmodule Jido.Connect.Google.PaginationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Pagination

  test "adds page token options to query maps" do
    assert Pagination.query(%{q: "name"}, page_token: "next", page_size: 50) == %{
             q: "name",
             pageToken: "next",
             pageSize: 50
           }

    assert Pagination.query(%{}, %{"page_token" => "next", "max_results" => 25}) == %{
             pageToken: "next",
             maxResults: 25
           }

    assert Pagination.query(%{q: "name"}, page_token: "", page_size: nil) == %{q: "name"}
  end

  test "extracts next page token and checkpoint metadata" do
    body = %{"nextPageToken" => "next"}

    assert Pagination.next_page_token(body) == "next"
    assert Pagination.next_page_token(:not_a_map) == nil
    assert Pagination.checkpoint(body, %{seen: 10}) == %{next_page_token: "next", seen: 10}
  end
end
