defmodule Jido.Connect.GmailTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Gmail

  test "declares Gmail provider metadata" do
    spec = Gmail.integration()

    assert spec.id == :gmail
    assert spec.package == :jido_connect_gmail
    assert spec.name == "Gmail"
    assert spec.category == :email
    assert spec.tags == [:google, :workspace, :email, :productivity]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/gmail.metadata" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.send" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.compose" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.modify" in profile.optional_scopes
    assert spec.actions == []
    assert spec.triggers == []
  end
end
