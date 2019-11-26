defmodule K8s.Middleware.Request.Initialize do
  @behaviour K8s.Middleware.Request
  @doc """

  ## Examples
      iex> conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.Registry.add(:test_cluster, conn)
      ...> request = %K8s.Middleware.Request{cluster: :test_cluster}
      ...> K8s.Middleware.Request.Initialize.call(request)      
      {:ok, %K8s.Middleware.Request{cluster: :test_cluster, headers: [{"Accept", "application/json"}, {"Content-Type", "application/json"}], opts: [ssl: [cert: ""]]}}
  """
  @impl true
  def call(%K8s.Middleware.Request{cluster: cluster, method: method, headers: headers, opts: opts} = req) do
    with {:ok, conn} <- K8s.Cluster.conn(cluster),
         {:ok, request_options} <- K8s.Conn.RequestOptions.generate(conn) do
      new_headers = K8s.http_provider().headers(method, request_options)
      updated_headers = Keyword.merge(headers, new_headers)
      updated_opts = Keyword.merge([ssl: request_options.ssl_options], opts)

      updated_request = %K8s.Middleware.Request{req| headers: updated_headers, opts: updated_opts}

      {:ok, updated_request}
    end
  end
end
