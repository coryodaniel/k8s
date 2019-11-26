defmodule K8s.MiddlewareTest do
  use ExUnit.Case, async: true
  doctest K8s.Middleware.Request.Initialize

  # TODO:
  # # K8s.Middleware.Request.EncodeBody
  # # K8s.Middleware.Request.DefaultParams
  # # K8s.Middleware.Request.DefaultHTTPOpts
  # # K8s.Middleware.Request.BaseURL (DiscoveryCluster?) 
  #     <- Actually this step is Cluster.url_for ... includes path...
  #     <- May need to visit after JIT Registry
  # Decide on K8s.Middleware behavior callback error types... {:error, t()} | {:error, String.t(), t()}
end
