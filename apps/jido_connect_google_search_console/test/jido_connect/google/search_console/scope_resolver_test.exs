defmodule Jido.Connect.Google.SearchConsole.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @write_scope "https://www.googleapis.com/auth/webmasters"

  test "returns readonly scope by default" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, [@readonly_scope])

    assert ScopeResolver.required_scopes(
             %{id: "google.search_console.search_analytics.query"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.search_console.url.inspect"},
             %{},
             %{scopes: []}
           ) == [@readonly_scope]
  end

  test "returns write scope for future site and sitemap mutations" do
    assert ScopeResolver.required_scopes(
             %{id: "google.search_console.site.add"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.search_console.sitemap.submit"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]
  end
end
