defmodule Jido.Connect.Slack.AppManifestTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Slack.AppManifest

  test "builds an oauth-only manifest by default" do
    manifest = AppManifest.build("https://demo.ngrok-free.app/", name: "Jido Connect Test")

    assert get_in(manifest, [:display_information, :name]) == "Jido Connect Test"

    assert get_in(manifest, [:oauth_config, :redirect_urls]) == [
             "https://demo.ngrok-free.app/integrations/slack/oauth/callback"
           ]

    assert get_in(manifest, [:oauth_config, :scopes, :bot]) == [
             "channels:read",
             "channels:history",
             "im:write",
             "mpim:write",
             "chat:write",
             "files:write",
             "reactions:read",
             "reactions:write"
           ]

    refute get_in(manifest, [:settings, :event_subscriptions])
    refute get_in(manifest, [:settings, :interactivity])
  end

  test "can include events and interactivity routes" do
    manifest =
      AppManifest.build("https://demo.ngrok-free.app",
        include_events?: true,
        include_interactivity?: true
      )

    assert get_in(manifest, [:oauth_config, :scopes, :bot]) == [
             "channels:read",
             "channels:history",
             "im:write",
             "mpim:write",
             "chat:write",
             "files:write",
             "reactions:read",
             "reactions:write",
             "app_mentions:read",
             "groups:history",
             "im:history",
             "mpim:history"
           ]

    assert get_in(manifest, [:settings, :event_subscriptions]) == %{
             request_url: "https://demo.ngrok-free.app/integrations/slack/events",
             bot_events: [
               "app_mention",
               "message.channels",
               "message.groups",
               "message.im",
               "message.mpim",
               "reaction_added"
             ]
           }

    assert get_in(manifest, [:settings, :interactivity]) == %{
             is_enabled: true,
             request_url: "https://demo.ngrok-free.app/integrations/slack/interactivity"
           }
  end

  test "encodes a Slack app creation URL" do
    manifest = AppManifest.build("https://demo.ngrok-free.app", name: "Jido Connect Test")
    url = AppManifest.creation_url(manifest)

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "api.slack.com"
    assert uri.path == "/apps"
    assert params["new_app"] == "1"

    assert Jason.decode!(params["manifest_json"])["display_information"]["name"] ==
             "Jido Connect Test"
  end
end
