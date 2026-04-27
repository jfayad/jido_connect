import Config

config :jido_connect,
  catalog_modules: [Jido.Connect.GitHub, Jido.Connect.Slack]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
