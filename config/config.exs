# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :k8s,
  auth_providers: [],
  clusters: %{}

import_config "#{Mix.env()}.exs"
