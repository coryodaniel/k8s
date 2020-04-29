defmodule K8s.Conn.Config do
  @moduledoc """
  Add runtime cluster configuration with environment variables.

  Each variable consists of a prefix that determines where the value will be placed in the config
  and a suffix that is the cluster name.

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

  @doc """
  Returns runtime and compile time cluster configuration merged together.
  """
  @spec all() :: map()
  def all() do
    merge_configs(runtime_cluster_configs(), compiletime_cluster_configs())
  end

  @spec compiletime_cluster_configs() :: map()
  def compiletime_cluster_configs() do
    Application.get_env(:k8s, :clusters, %{})
  end

  @doc """
  Cluster configuration read from env variables.
  To be merged over `Application.get_env(:k8s, :clusters)`.

  ## Examples
    Only specifying compiletime configs
      iex> config = %{"dev" => %{conn: "runtime/path/to/dev.kubeconfig.yaml"}}
      ...> K8s.Conn.Config.merge_configs(%{}, config)
      %{"dev" => %{conn: "runtime/path/to/dev.kubeconfig.yaml"}}

    Only specifying runtime configs
      iex> env = %{"K8S_CLUSTER_CONF_PATH_dev" => "runtime/path/to/dev.kubeconfig.yaml"}
      ...> K8s.Conn.Config.merge_configs(env, %{})
      %{"dev" => %{conn: "runtime/path/to/dev.kubeconfig.yaml"}}

    Overriding compile time configs

      iex> env = %{"K8S_CLUSTER_CONF_PATH_dev" => "runtime/path/to/dev.kubeconfig.yaml"}
      ...> compile_config = %{"dev" => %{conn: "compiletime/path/to/dev.kubeconfig.yaml"}}
      ...> K8s.Conn.Config.merge_configs(env, compile_config)
      %{"dev" => %{conn: "runtime/path/to/dev.kubeconfig.yaml"}}

    Merging compile time configs

      iex> env = %{"K8S_CLUSTER_CONF_CONTEXT_dev" => "runtime-context"}
      ...> compile_config = %{"dev" => %{conn: "compiletime/path/to/dev.kubeconfig.yaml"}}
      ...> K8s.Conn.Config.merge_configs(env, compile_config)
      %{"dev" => %{conn: "compiletime/path/to/dev.kubeconfig.yaml", conn_opts: [context: "runtime-context"]}}

    Adding clusters at runtime

      iex> env = %{"K8S_CLUSTER_CONF_PATH_us_east" => "runtime/path/to/us_east.kubeconfig.yaml", "K8S_CLUSTER_CONF_CONTEXT_us_east" => "east-context"}
      ...> compile_config = %{"us_west" => %{conn: "compiletime/path/to/us_west.kubeconfig.yaml"}}
      ...> K8s.Conn.Config.merge_configs(env, compile_config)
      %{"us_east" => %{conn: "runtime/path/to/us_east.kubeconfig.yaml", conn_opts: [context: "east-context"]}, "us_west" => %{conn: "compiletime/path/to/us_west.kubeconfig.yaml"}}
  """
  @spec merge_configs(map, map) :: map
  def merge_configs(env_vars, config) do
    Enum.reduce(env_vars, config, fn {k, v}, acc ->
      cluster_name = k |> cluster_name()
      acc_cluster_config = Map.get(acc, cluster_name, %{})

      {new_key, new_value} = get_config_kv(k, v)
      updated_cluster_conn = Map.put(acc_cluster_config, new_key, new_value)

      Map.put(acc, cluster_name, updated_cluster_conn)
    end)
  end

  # given an env var name/value, map the config to the correct cluster
  defp get_config_kv(@env_var_context_prefix <> _cluster_name, conn_opts_context),
    do: {:conn_opts, [context: conn_opts_context]}

  # given an env var name/value, map the config to the correct cluster
  defp get_config_kv(@env_var_path_prefix <> _cluster_name, conn_path), do: {:conn, conn_path}
  defp get_config_kv(@env_var_sa_prefix <> _cluster_name, "true"), do: {:use_sa, true}
  defp get_config_kv(@env_var_sa_prefix <> _cluster_name, "false"), do: {:use_sa, false}

  # given an env var name, map it to the correct cluster
  defp cluster_name(@env_var_context_prefix <> cluster_name), do: cluster_name
  defp cluster_name(@env_var_path_prefix <> cluster_name), do: cluster_name
  defp cluster_name(@env_var_sa_prefix <> cluster_name), do: cluster_name

  @spec runtime_cluster_configs() :: map
  @doc "Parses ENV variables to runtime cluster configs"
  def runtime_cluster_configs(), do: Map.take(System.get_env(), env_keys())

  @spec env_keys() :: list(binary)
  defp env_keys() do
    System.get_env()
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, @env_var_prefix))
  end
end
