defmodule Jido.Connect.ErrorTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error

  test "builds structured auth errors" do
    error = Error.missing_scopes("conn_1", ["repo"])

    assert %Error.AuthError{} = error
    assert error.class == :auth
    assert error.reason == :missing_scopes
    assert error.connection_id == "conn_1"
    assert error.missing_scopes == ["repo"]
  end

  test "builds each public error type" do
    assert %Error.ValidationError{message: "bad"} = Error.validation("bad")
    assert %Error.AuthError{message: "auth"} = Error.auth("auth")

    assert %Error.ProviderError{message: "provider", provider: :demo} =
             Error.provider("provider", %{provider: :demo})

    assert %Error.ConfigError{message: "config", key: :demo} =
             Error.config("config", %{key: :demo})

    assert %Error.ExecutionError{message: "execution", phase: :run} =
             Error.execution("execution", phase: :run)

    assert %Error.InternalError{message: "internal"} = Error.internal("internal")

    assert %Error.ValidationError{reason: :input, details: %{errors: [:bad], operation: :parse}} =
             Error.zoi(:input, :bad, %{operation: :parse})

    assert %Error.AuthError{reason: :connection_required, details: %{action_id: "demo"}} =
             Error.connection_required(%{action_id: "demo"})
  end

  test "converts unknown values through Splode" do
    assert %{class: :internal, message: "boom"} = Error.to_map("boom")
  end
end
