defmodule Mix.Tasks.Jido.Connect.Slack.App.ManifestUrl do
  @moduledoc """
  Generates a Slack app creation URL from a manifest.

      mix jido.connect.slack.app.manifest_url
      mix jido.connect.slack.app.manifest_url --url https://example.ngrok-free.app
      mix jido.connect.slack.app.manifest_url --events --interactivity --open

  If `--url` is omitted, the task uses `JIDO_SLACK_PUBLIC_URL`,
  `JIDO_PUBLIC_URL`, or a running ngrok HTTPS tunnel from
  `http://127.0.0.1:4040/api/tunnels`.
  """

  use Mix.Task

  alias Jido.Connect.Slack.AppManifest

  @shortdoc "Generates a Slack app manifest creation URL"
  @ngrok_api ~c"http://127.0.0.1:4040/api/tunnels"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          bot_name: :string,
          description: :string,
          events: :boolean,
          interactivity: :boolean,
          name: :string,
          open: :boolean,
          output: :string,
          url: :string
        ]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    base_url = base_url!(opts)

    manifest =
      AppManifest.build(base_url,
        name: Keyword.get(opts, :name, AppManifest.default_app_name()),
        description: Keyword.get(opts, :description, "Local Jido Connect Slack test app."),
        bot_display_name: Keyword.get(opts, :bot_name, "Jido Connect"),
        include_events?: Keyword.get(opts, :events, false),
        include_interactivity?: Keyword.get(opts, :interactivity, false)
      )

    creation_url = AppManifest.creation_url(manifest)
    output = Keyword.get(opts, :output, ".secrets/slack-app-manifest")

    write_outputs!(output, manifest, creation_url)
    print_summary(base_url, manifest, creation_url, output)
    maybe_open(creation_url, opts)
  end

  defp base_url!(opts) do
    opts[:url] || System.get_env("JIDO_SLACK_PUBLIC_URL") || System.get_env("JIDO_PUBLIC_URL") ||
      ngrok_url!()
  end

  defp ngrok_url! do
    case :httpc.request(:get, {@ngrok_api, []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body
        |> Jason.decode!()
        |> Map.get("tunnels", [])
        |> Enum.find_value(fn tunnel ->
          public_url = Map.get(tunnel, "public_url")

          if is_binary(public_url) and String.starts_with?(public_url, "https://") do
            public_url
          end
        end) || Mix.raise("no HTTPS ngrok tunnel found")

      _other ->
        Mix.raise("pass --url or start ngrok before generating the Slack manifest URL")
    end
  rescue
    _error -> Mix.raise("pass --url or start ngrok before generating the Slack manifest URL")
  end

  defp write_outputs!(output, manifest, creation_url) do
    File.mkdir_p!(Path.dirname(output))
    File.write!(output <> ".json", Jason.encode!(manifest, pretty: true))
    File.write!(output <> ".url", creation_url <> "\n")
  end

  defp print_summary(base_url, manifest, creation_url, output) do
    scopes = get_in(manifest, [:oauth_config, :scopes, :bot])
    events? = get_in(manifest, [:settings, :event_subscriptions]) != nil
    interactivity? = get_in(manifest, [:settings, :interactivity]) != nil

    Mix.shell().info("""
    Wrote #{output}.json
    Wrote #{output}.url

    Slack app manifest:
    Name:                     #{get_in(manifest, [:display_information, :name])}
    Public URL:               #{base_url}
    OAuth Redirect URL:       #{AppManifest.oauth_callback_url(base_url)}
    Events Request URL:       #{AppManifest.events_url(base_url)}#{included(events?, "--events")}
    Interactivity Request URL: #{AppManifest.interactivity_url(base_url)}#{included(interactivity?, "--interactivity")}
    Bot scopes:               #{Enum.join(scopes, ",")}

    Open this URL to create the Slack app:
    #{creation_url}

    After Slack creates the app, copy these into .env:
    SLACK_CLIENT_ID=
    SLACK_CLIENT_SECRET=
    SLACK_SIGNING_SECRET=
    SLACK_BOT_TOKEN=
    """)
  end

  defp included(true, _flag), do: " (included)"
  defp included(false, flag), do: " (not included; pass #{flag})"

  defp maybe_open(creation_url, opts) do
    if Keyword.get(opts, :open, false) do
      System.cmd("open", [creation_url])
      :ok
    end
  end
end
