import Config

config :logger, :console,
  format: "$time [$level] $message $metadata\n",
  metadata: [:file]

import_config "#{Mix.env()}.exs"
