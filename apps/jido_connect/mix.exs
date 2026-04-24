defmodule JidoConnectCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect,
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
      mod: {Jido.Connect.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jido, "~> 2.2"},
      {:jido_action, "~> 2.2"},
      {:jido_signal, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:spark, "~> 2.6"},
      {:zoi, "~> 0.17.1"}
    ]
  end
end
