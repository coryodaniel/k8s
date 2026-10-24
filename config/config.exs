import Config

config :logger, :default_formatter,
  format: "$time [$level] $message $metadata\n",
  metadata: [:file, :library, :error, :object, :body, :measurements, :metadata]

# Configure K8s to use Glazer JSON and YAML libraries:
# config :k8s,
#   json_library: Glazer.JSON,
#   yaml_library: K8s.Yaml.Glazer

import_config "#{Mix.env()}.exs"
