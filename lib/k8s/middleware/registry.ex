# Registry should be the agent... MIddleware should be the API
# K8s.Middleware.request(cluster_name, ...?)
# Adds a piece of middleware to the stack
# K8s.Middleware.Registry.add(cluster_name, :request, func_or_module)
#
# K8s.Middleware.Registry.defaults(:request)
#
# Replaces the existing stack, including defaults
# K8s.Middleware.Registry.set(cluster_name, :request, list(func_or_module))
