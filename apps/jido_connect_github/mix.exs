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
      {:jido_connect, in_umbrella: true},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.19", only: :test},
      {:req, "~> 0.5"}
    ]
  end
end
