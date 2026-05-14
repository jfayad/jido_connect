defmodule Jido.Connect.Google.SearchConsoleTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @write_scope "https://www.googleapis.com/auth/webmasters"

  test "declares Google Search Console provider metadata" do
    spec = SearchConsole.integration()

    assert spec.id == :google_search_console
    assert spec.package == :jido_connect_google_search_console
    assert spec.name == "Google Search Console"
    assert spec.category == :marketing
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :search, :seo, :marketing]
    assert spec.actions == []
    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(SearchConsole,
      otp_app: :jido_connect_google_search_console,
      action_modules: [],
      plugin_module: Jido.Connect.Google.SearchConsole.Plugin,
      plugin_name: "google_search_console"
    )
  end
end
