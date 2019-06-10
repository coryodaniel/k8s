defmodule K8s.Config do
  @moduledoc """
  Add runtime cluster configuration with environment variables.

  Each variable consists of a prefix that determines where the value will be placed in the config
  and a suffix that is the cluster name. The cluster name will be atomized.

  Environment Variable Prefixes:
  * `K8S_CLUSTER_CONF_SA_` - *boolean* enables authentication to the k8s API with the pods `spec.serviceAccountName`.
  * `K8S_CLUSTER_CONF_PATH_` - *string* absolute path to the kube config file.
  * `K8S_CLUSTER_CONF_CONTEXT_` *string* which context to use in the kube config file.

  ## Examples
    ```shell
    export K8S_CLUSTER_CONF_SA_us_central=true
    export K8S_CLUSTER_CONF_PATH_us_east="east.yaml"
    export K8S_CLUSTER_CONF_CONTEXT_us_east="east"
    export K8S_CLUSTER_CONF_PATH_us_west="west.yaml"
    export K8S_CLUSTER_CONF_CONTEXT_us_west="west"
    ```
  """

  @env_var_prefix "K8S_CLUSTER_CONF_"
  @env_var_sa_prefix "K8S_CLUSTER_CONF_SA_"
  @env_var_path_prefix "K8S_CLUSTER_CONF_PATH_"
  @env_var_context_prefix "K8S_CLUSTER_CONF_CONTEXT_"
  @env_var_discovery_timeout_prefix "K8S_DISCOVERY_TIMEOUT_"

  @default_discover_timeout_ms 10_000

  @doc """
  Returns runtime and compile time cluster configuration merged together.
  """
  @spec clusters() :: map
  def clusters() do
    compile_time_clusters_config = Application.get_env(:k8s, :clusters, %{})
    runtime_clusters_config(env(), compile_time_clusters_config)
  end

  @doc """
  Discovery HTTP call timeouts in ms for each API endpoint. API endpoints are discovered in parallel. This controls the timeout for any given HTTP request.

  ## Examples
    ```shell
    export K8S_DISCOVERY_TIMEOUT_us_central=10000
    ```
  """
  @spec discovery_http_timeout(atom | binary) :: pos_integer
  def discovery_http_timeout(cluster_name) do
    "#{@env_var_discovery_timeout_prefix}#{cluster_name}"
    |> System.get_env()
    |> parse_discovery_http_timeout
  end

  @spec parse_discovery_http_timeout(nil | binary | {pos_integer, any}) :: pos_integer
  defp parse_discovery_http_timeout(nil), do: @default_discover_timeout_ms
  defp parse_discovery_http_timeout({ms, _}), do: ms

  defp parse_discovery_http_timeout(ms) when is_binary(ms) do
    ms |> Integer.parse() |> parse_discovery_http_timeout
  end

  @doc """
  Cluster configuration read from env variables.
  To be merged over `Application.get_env(:k8s, :clusters)`.

  ## Examples
    Overriding compile time configs

      iex> env = %{"K8S_CLUSTER_CONF_PATH_dev" => "runtime/path/to/dev.conf"}
      ...> compile_config = %{dev: %{conf: "compiletime/path/to/dev.conf"}}
      ...> K8s.Config.runtime_clusters_config(env, compile_config)
      %{dev: %{conf: "runtime/path/to/dev.conf"}}

    Merging compile time configs

      iex> env = %{"K8S_CLUSTER_CONF_CONTEXT_dev" => "runtime-context"}
      ...> compile_config = %{dev: %{conf: "compiletime/path/to/dev.conf"}}
      ...> K8s.Config.runtime_clusters_config(env, compile_config)
      %{dev: %{conf: "compiletime/path/to/dev.conf", conf_opts: [context: "runtime-context"]}}

    Adding clusters at runtime

      iex> env = %{"K8S_CLUSTER_CONF_PATH_us_east" => "runtime/path/to/us_east.conf", "K8S_CLUSTER_CONF_CONTEXT_us_east" => "east-context"}
      ...> compile_config = %{us_west: %{conf: "compiletime/path/to/us_west.conf"}}
      ...> K8s.Config.runtime_clusters_config(env, compile_config)
      %{us_east: %{conf: "runtime/path/to/us_east.conf", conf_opts: [context: "east-context"]}, us_west: %{conf: "compiletime/path/to/us_west.conf"}}
  """
  @spec runtime_clusters_config(map, map) :: map
  def runtime_clusters_config(env_vars, config) do
    Enum.reduce(env_vars, config, fn {k, v}, acc ->
      cluster_name = k |> cluster_name() |> String.to_atom()
      acc_cluster_config = Map.get(acc, cluster_name, %{})

      {new_key, new_value} = get_config_kv(k, v)
      updated_cluster_conf = Map.put(acc_cluster_config, new_key, new_value)

      Map.put(acc, cluster_name, updated_cluster_conf)
    end)
  end

  # given an env var name/value, map the config to the correct cluster
  defp get_config_kv(@env_var_context_prefix <> _cluster_name, conf_opts_context),
    do: {:conf_opts, [context: conf_opts_context]}

  # given an env var name/value, map the config to the correct cluster
  defp get_config_kv(@env_var_path_prefix <> _cluster_name, conf_path), do: {:conf, conf_path}
  defp get_config_kv(@env_var_sa_prefix <> _cluster_name, "true"), do: {:use_sa, true}
  defp get_config_kv(@env_var_sa_prefix <> _cluster_name, "false"), do: {:use_sa, false}

  # given an env var name, map it to the correct cluster
  defp cluster_name(@env_var_context_prefix <> cluster_name), do: cluster_name
  defp cluster_name(@env_var_path_prefix <> cluster_name), do: cluster_name
  defp cluster_name(@env_var_sa_prefix <> cluster_name), do: cluster_name

  @spec env() :: map
  @doc "Subset of env vars applicable to k8s"
  def env(), do: Map.take(System.get_env(), env_keys())

  @spec env_keys() :: list(binary)
  defp env_keys() do
    System.get_env()
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, @env_var_prefix))
  end
end
