defmodule Jido.Connect.Slack.AppManifest do
  @moduledoc """
  Builds Slack app manifests for local Jido Connect demos.

  The manifest is intentionally small: it configures a bot user, OAuth redirect
  URLs, and the scopes required by the first generated Slack actions. Event and
  interactivity URLs are opt-in so hosts can enable them after local routes are
  ready to answer Slack's verification requests.
  """

  @default_scopes [
    "channels:read",
    "channels:history",
    "chat:write",
    "files:write",
    "reactions:write"
  ]
  @event_scopes [
    "app_mentions:read",
    "channels:history",
    "groups:history",
    "im:history",
    "mpim:history"
  ]

  @type option ::
          {:name, String.t()}
          | {:description, String.t()}
          | {:bot_display_name, String.t()}
          | {:scopes, [String.t()]}
          | {:include_events?, boolean()}
          | {:include_interactivity?, boolean()}

  @doc """
  Builds a Slack manifest map for a public host URL.
  """
  @spec build(String.t(), [option()]) :: map()
  def build(base_url, opts \\ []) when is_binary(base_url) and is_list(opts) do
    base_url = String.trim_trailing(base_url, "/")
    include_events? = Keyword.get(opts, :include_events?, false)
    include_interactivity? = Keyword.get(opts, :include_interactivity?, false)
    scopes = scopes(opts, include_events?)

    %{
      display_information: %{
        name: Keyword.get(opts, :name, default_app_name()),
        description: Keyword.get(opts, :description, "Local Jido Connect Slack test app."),
        background_color: "#1f2937"
      },
      features: %{
        bot_user: %{
          display_name: Keyword.get(opts, :bot_display_name, "Jido Connect"),
          always_online: false
        }
      },
      oauth_config: %{
        redirect_urls: [oauth_callback_url(base_url)],
        scopes: %{
          bot: scopes
        }
      },
      settings: %{
        org_deploy_enabled: false,
        socket_mode_enabled: false,
        token_rotation_enabled: false
      }
    }
    |> maybe_put_event_subscriptions(base_url, include_events?)
    |> maybe_put_interactivity(base_url, include_interactivity?)
  end

  @doc """
  Builds Slack's app-creation URL with a URL-encoded JSON manifest.
  """
  @spec creation_url(map()) :: String.t()
  def creation_url(manifest) when is_map(manifest) do
    "https://api.slack.com/apps?" <>
      URI.encode_query(%{
        "new_app" => "1",
        "manifest_json" => Jason.encode!(manifest)
      })
  end

  @doc false
  @spec default_app_name() :: String.t()
  def default_app_name do
    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "Jido Connect Dev #{suffix}"
  end

  @doc false
  @spec oauth_callback_url(String.t()) :: String.t()
  def oauth_callback_url(base_url),
    do: String.trim_trailing(base_url, "/") <> "/integrations/slack/oauth/callback"

  @doc false
  @spec events_url(String.t()) :: String.t()
  def events_url(base_url),
    do: String.trim_trailing(base_url, "/") <> "/integrations/slack/events"

  @doc false
  @spec interactivity_url(String.t()) :: String.t()
  def interactivity_url(base_url),
    do: String.trim_trailing(base_url, "/") <> "/integrations/slack/interactivity"

  defp scopes(opts, include_events?) do
    opts
    |> Keyword.get(:scopes, @default_scopes)
    |> Kernel.++(if include_events?, do: @event_scopes, else: [])
    |> Enum.uniq()
  end

  defp maybe_put_event_subscriptions(manifest, _base_url, false), do: manifest

  defp maybe_put_event_subscriptions(manifest, base_url, true) do
    put_in(manifest, [:settings, :event_subscriptions], %{
      request_url: events_url(base_url),
      bot_events: [
        "app_mention",
        "message.channels",
        "message.groups",
        "message.im",
        "message.mpim"
      ]
    })
  end

  defp maybe_put_interactivity(manifest, _base_url, false), do: manifest

  defp maybe_put_interactivity(manifest, base_url, true) do
    put_in(manifest, [:settings, :interactivity], %{
      is_enabled: true,
      request_url: interactivity_url(base_url)
    })
  end
end
