defmodule Jido.Connect.Demo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Jido.Connect.DemoWeb.Telemetry,
      Jido.Connect.Demo.Store,
      {DNSCluster, query: Application.get_env(:jido_connect_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Jido.Connect.Demo.PubSub},
      # Start a worker by calling: Jido.Connect.Demo.Worker.start_link(arg)
      # {Jido.Connect.Demo.Worker, arg},
      # Start to serve requests, typically the last entry
      Jido.Connect.DemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jido.Connect.Demo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Jido.Connect.DemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
