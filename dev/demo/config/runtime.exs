import Config

if System.get_env("PHX_SERVER") do
  config :jido_connect_demo, Jido.Connect.DemoWeb.Endpoint, server: true
end

config :jido_connect_demo, Jido.Connect.DemoWeb.Endpoint,
  http: [
    port:
      String.to_integer(
        System.get_env("PORT") ||
          System.get_env("JIDO_CONNECT_DEMO_PORT") ||
          System.get_env("JIDO_GITHUB_DEMO_PORT") ||
          "4000"
      )
  ]

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :jido_connect_demo, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :jido_connect_demo, Jido.Connect.DemoWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base
end
