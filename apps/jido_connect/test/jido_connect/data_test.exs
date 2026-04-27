defmodule Jido.Connect.DataTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Data

  test "gets string and existing atom key variants without atomizing arbitrary input" do
    assert Data.get(%{"id" => "string"}, :id) == "string"
    assert Data.get(%{id: "atom"}, "id") == "atom"

    assert Data.get(%{}, "not_an_existing_atom_#{System.unique_integer()}", :fallback) ==
             :fallback
  end

  test "compacts provider request maps" do
    assert Data.compact(%{a: 1, b: nil, c: "", d: false}) == %{a: 1, d: false}
  end

  test "fetches and safely atomizes existing keys" do
    assert Data.fetch!(%{"id" => "123"}, :id) == "123"
    assert_raise KeyError, fn -> Data.fetch!(%{}, :missing) end

    assert Data.atomize_existing_keys(%{
             "id" => "123",
             "not_existing_#{System.unique_integer()}" => "kept"
           })[
             :id
           ] == "123"
  end
end
