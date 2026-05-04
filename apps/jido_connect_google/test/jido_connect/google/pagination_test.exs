defmodule Jido.Connect.Google.PaginationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Pagination

  test "adds page token options to query maps" do
    assert Pagination.query(%{q: "name"}, page_token: "next", page_size: 50) == %{
             q: "name",
             pageToken: "next",
             pageSize: 50
           }
  end

  test "extracts next page token and checkpoint metadata" do
    body = %{"nextPageToken" => "next"}

    assert Pagination.next_page_token(body) == "next"
    assert Pagination.checkpoint(body, %{seen: 10}) == %{next_page_token: "next", seen: 10}
  end
end
