defmodule Jido.Connect.Google.AccountTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Account

  test "normalizes Google userinfo payloads" do
    assert {:ok, account} =
             Account.from_userinfo(%{
               "sub" => "123",
               "email" => "user@example.com",
               "email_verified" => true,
               "name" => "User Name",
               "hd" => "example.com",
               "picture" => "https://example.com/avatar.png",
               "locale" => "en"
             })

    assert account.id == "123"
    assert account.email == "user@example.com"
    assert account.verified_email? == true
    assert account.display_name == "User Name"
    assert account.hosted_domain == "example.com"

    assert Account.to_subject(account) == %{
             google_account_id: "123",
             email: "user@example.com",
             display_name: "User Name",
             hosted_domain: "example.com"
           }
  end

  test "supports alternate profile ids, metadata, and direct constructors" do
    assert %Account{email: "direct@example.com", metadata: %{source: :direct}} =
             Account.new!(%{email: "direct@example.com", metadata: %{source: :direct}})

    assert {:ok, account} =
             Account.from_userinfo(
               %{"id" => "legacy-123", "email" => "legacy@example.com"},
               %{source: :userinfo}
             )

    assert account.id == "legacy-123"
    assert account.email == "legacy@example.com"
    assert account.verified_email? == false
    assert account.metadata == %{source: :userinfo}
    assert Account.schema()
  end
end
