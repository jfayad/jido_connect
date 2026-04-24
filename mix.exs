defmodule JidoConnect.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      name: "Jido Connect",
      source_url: "https://github.com/mikehostetler/jido_connect",
      docs: docs(),
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:ex_doc, "~> 0.36", only: :docs, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "docs/authoring_integrations.md",
        "docs/generated_jido_modules.md",
        "docs/host_owned_storage.md",
        "docs/github_auth.md",
        "docs/github_webhooks.md",
        "docs/github_end_to_end.md",
        "docs/release_checklist.md"
      ],
      groups_for_extras: [
        Guides: ~r/docs\/.*/
      ]
    ]
  end
end
