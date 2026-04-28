import Config

config :jido_connect,
  catalog_modules: [Jido.Connect.GitHub, Jido.Connect.Slack, Jido.Connect.MCP]

config :spark, :formatter,
  remove_parens?: true,
  "Jido.Connect": [
    extensions: [Jido.Connect.Dsl.Extension]
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
