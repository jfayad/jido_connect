import Config

config :jido_connect_demo, Jido.Connect.DemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "jido_connect_demo_test_secret_key_base_change_me_for_real_hosts_0123456789abcdef",
  server: false

config :logger, level: :warning

config :jido_connect_demo, read_dotenv?: false

config :phoenix, :plug_init_mode, :runtime
