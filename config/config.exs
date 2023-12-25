import Config

config :logger, :default_formatter,
  format: "$time [$level] $message $metadata\n",
  metadata: [:file, :library, :error, :object, :body, :measurements, :metadata]

import_config "#{Mix.env()}.exs"
