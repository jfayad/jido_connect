defmodule Jido.Connect.ScopeSecurityTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Scope, ScopeRequirements, Security}

  defmodule TwoArgScopeResolver do
    def required_scopes(_operation, _input), do: ["repo", :repo, nil]
  end

  defmodule InvalidScopeResolver do
    def required_scopes(_operation, _input, _connection), do: :invalid
  end

  test "parses and encodes common provider scope formats" do
    assert Scope.parse("repo read:user,chat:write") == ["repo", "read:user", "chat:write"]
    assert Scope.parse(nil) == []
    assert Scope.parse(["repo"]) == ["repo"]

    assert Scope.encode(["channels:read", "chat:write"], separator: ",") ==
             "channels:read,chat:write"

    assert Scope.encode("repo", separator: ",") == "repo"
  end

  test "verifies HMACs without leaking comparison behavior to callers" do
    signature = Security.hmac_sha256_hex("secret", "payload")

    assert Security.secure_compare?(signature, Security.hmac_sha256_hex("secret", "payload"))
    refute Security.secure_compare?(signature, Security.hmac_sha256_hex("other", "payload"))
    refute Security.secure_compare?(signature, "short")
  end

  test "resolves static and dynamic operation scopes" do
    assert ScopeRequirements.required_scopes(%{scopes: ["repo", :repo, nil]}) == {:ok, ["repo"]}

    assert ScopeRequirements.required_scopes(%{scope_resolver: TwoArgScopeResolver}, %{}) ==
             {:ok, ["repo"]}

    assert {:error, %Jido.Connect.Error.ConfigError{key: :scope_resolver}} =
             ScopeRequirements.required_scopes(%{scope_resolver: InvalidScopeResolver}, %{})
  end
end
