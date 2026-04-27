defmodule JidoConnectMCP.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_connect_mcp,
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
      test_coverage: test_coverage(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Jido.Connect.MCP.Application, []}
    ]
  end

  defp deps do
    [
      jido_connect_dep(),
      jido_mcp_dep(),
      {:jason, "~> 1.4"},
      {:plug, "~> 1.19"}
    ]
  end

  defp jido_connect_dep do
    if hex_package_task?() do
      {:jido_connect, "~> 0.1"}
    else
      {:jido_connect, in_umbrella: true}
    end
  end

  defp jido_mcp_dep do
    if hex_package_task?() do
      {:jido_mcp, "~> 0.1"}
    else
      {:jido_mcp, github: "agentjido/jido_mcp", branch: "main", override: true}
    end
  end

  defp hex_package_task? do
    Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
  end

  defp description do
    "MCP bridge package for Jido Connect, exposing allowlisted MCP endpoints and tools through generated Jido actions."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mikehostetler/jido_connect",
        "Docs" => "https://hexdocs.pm/jido_connect_mcp"
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

  defp test_coverage do
    [
      summary: [threshold: 80],
      ignore_modules: [
        Jido.Connect.MCP.Application
      ]
    ]
  end
end
