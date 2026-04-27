defmodule Mix.Tasks.Jido.Connect.Github.App.Manifest do
  @moduledoc """
  Generates a GitHub App manifest registration page.

      mix jido.connect.github.app.manifest
      mix jido.connect.github.app.manifest --url https://example.ngrok-free.app --open
      mix jido.connect.github.app.manifest --owner my-org --open

  If `--url` is omitted, the task uses `JIDO_GITHUB_PUBLIC_URL` or a running
  ngrok HTTPS tunnel from `http://127.0.0.1:4040/api/tunnels`.
  """

  use Mix.Task

  alias Jido.Connect.Dev.PublicUrl

  @shortdoc "Generates a GitHub App manifest registration page"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          name: :string,
          owner: :string,
          output: :string,
          open: :boolean,
          url: :string
        ]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    base_url = PublicUrl.resolve!(opts, ["JIDO_GITHUB_PUBLIC_URL", "JIDO_PUBLIC_URL"])
    name = Keyword.get(opts, :name, default_app_name())
    output = Keyword.get(opts, :output, ".secrets/github-app-manifest.html")
    action = github_form_action(Keyword.get(opts, :owner))
    state = random_state()
    manifest = manifest(name, base_url)

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, html(action, state, manifest))

    Mix.shell().info("""
    Wrote #{output}

    GitHub App manifest:
    Name:          #{name}
    Public URL:    #{base_url}
    Callback URL:  #{base_url}/integrations/github/oauth/callback
    Setup URL:     #{base_url}/integrations/github/setup
    Webhook URL:   #{base_url}/integrations/github/webhook

    Open the file and submit the form. GitHub will redirect to:
    #{base_url}/integrations/github/setup/complete?code=...

    Then run:
    mix jido.connect.github.app.convert CODE
    """)

    maybe_open(output, opts)
  end

  defp default_app_name do
    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "Jido Connect Dev #{suffix}"
  end

  defp github_form_action(nil), do: "https://github.com/settings/apps/new"

  defp github_form_action(owner),
    do: "https://github.com/organizations/#{owner}/settings/apps/new"

  defp manifest(name, base_url) do
    %{
      name: name,
      url: base_url,
      hook_attributes: %{
        url: base_url <> "/integrations/github/webhook",
        active: true
      },
      redirect_url: base_url <> "/integrations/github/setup/complete",
      callback_urls: [base_url <> "/integrations/github/oauth/callback"],
      setup_url: base_url <> "/integrations/github/setup",
      description: "Local Jido Connect GitHub test app.",
      public: false,
      default_permissions: %{
        metadata: "read",
        issues: "write"
      },
      default_events: ["issues"],
      request_oauth_on_install: true,
      setup_on_update: true
    }
  end

  defp html(action, state, manifest) do
    manifest_json = Jason.encode!(manifest, pretty: true)

    """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>Register GitHub App</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 2rem; max-width: 880px; }
          button { font: inherit; padding: 0.5rem 0.75rem; }
          textarea { width: 100%; height: 28rem; margin-top: 1rem; font-family: ui-monospace, monospace; }
        </style>
      </head>
      <body>
        <h1>Register GitHub App</h1>
        <form action="#{html_escape(action)}?state=#{html_escape(state)}" method="post">
          <input type="hidden" name="manifest" value="#{html_escape(Jason.encode!(manifest))}">
          <button type="submit">Create GitHub App</button>
        </form>
        <textarea readonly>#{html_escape(manifest_json)}</textarea>
      </body>
    </html>
    """
  end

  defp html_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp random_state, do: :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

  defp maybe_open(output, opts) do
    if Keyword.get(opts, :open, false) do
      System.cmd("open", [output])
      :ok
    end
  end
end
