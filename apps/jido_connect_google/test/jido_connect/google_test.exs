defmodule Jido.Connect.GoogleTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google

  test "exposes shared Google provider metadata" do
    assert Google.provider() == :google

    assert Google.auth_profiles() == [
             :user,
             :service_account,
             :domain_delegated_service_account
           ]
  end
end
