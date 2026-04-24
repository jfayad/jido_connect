import Config

port =
  System.get_env("JIDO_CONNECT_DEMO_PORT") ||
    System.get_env("JIDO_GITHUB_DEMO_PORT") ||
    "4000"

config :jido_connect_demo, Jido.Connect.DemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(port)],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "jido_connect_demo_dev_secret_key_base_change_me_for_real_hosts_0123456789abcdef",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:jido_connect_demo, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:jido_connect_demo, ~w(--watch)]}
  ]

config :jido_connect_demo, Jido.Connect.DemoWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/jido_connect_demo_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :default_handler, level: :debug

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
