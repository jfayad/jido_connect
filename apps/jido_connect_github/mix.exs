defmodule JidoConnectGitHub.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect_github,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/mikehostetler/jido_connect",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Jido.Connect.GitHub.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      jido_connect_dep(),
      {:jason, "~> 1.4"},
      {:plug, "~> 1.19", only: :test},
      {:req, "~> 0.5"}
    ]
  end

  defp jido_connect_dep do
    if hex_package_task?() do
      {:jido_connect, "~> 0.1"}
    else
      {:jido_connect, in_umbrella: true}
    end
  end

  defp hex_package_task? do
    Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
  end

  defp description do
    "GitHub provider package for Jido Connect, including generated Jido tools, OAuth, GitHub App auth, REST client, and webhook helpers."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mikehostetler/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect_github"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v0.1.0"
    ]
  end
end
