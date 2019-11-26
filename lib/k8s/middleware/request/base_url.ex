# defmodule K8s.Middleware.Request.BaseURL do
#   @behaviour K8s.Middleware.Request

#   @doc """

#   ## Examples
#       iex> conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
#       ...> K8s.Cluster.Registry.add(:test_cluster, conn)
#       ...> request = %K8s.Middleware.Request{cluster: :test_cluster}
#       ...> K8s.Middleware.Request.BaseURL.call(request)      
#       {:ok, %K8s.Middleware.Request{cluster: :test_cluster, url: "https://localhost:6443"}}
#   """
#   @impl true
#   def call(%K8s.Middleware.Request{} = req) do
#     {:ok, url} <- Cluster.url_for(operation, cluster_name)
#     {:ok, req}
#   end
# end
