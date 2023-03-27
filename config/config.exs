import Config

config :logger, :console,
  format: "$time [$level] $message $metadata\n",
  metadata: [:file, :library, :error, :object, :body, :measurements, :metadata, :message]

import_config "#{Mix.env()}.exs"
