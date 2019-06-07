defmodule K8s.Config do
  # credo:disable-for-this-file
  @moduledoc """
  K8s runtime configuration
  """

  @env_var_prefix "K8S_CLUSTER_CONF_"
  @env_var_sa_prefix "K8S_CLUSTER_CONF_SA_"
  @env_var_path_prefix "K8S_CLUSTER_CONF_PATH_"
  @env_var_context_prefix "K8S_CLUSTER_CONF_CONTEXT_"

  def all() do
    compile_time_clusters_config = Application.get_env(:k8s, :clusters)
    clusters = runtime_clusters_config(compile_time_clusters_config)
  end

  @doc """
  Cluster configuration read from env variables.
  To be merged over `Application.get_env(:k8s, :clusters)`.
  """
  @spec runtime_clusters_config(map) :: map
  def runtime_clusters_config(config) do
    Enum.reduce(env(), config, fn {k, v}, acc ->
      cluster_name = k |> cluster_name() |> String.to_atom()
      acc_cluster_config = Map.get(acc, cluster_name, %{})

      {new_key, new_value} = get_config_kv(k, v)
      updated_cluster_conf = Map.put(acc_cluster_config, new_key, new_value)

      Map.put(acc, cluster_name, updated_cluster_conf)
    end)
  end

  def get_config_kv(@env_var_context_prefix <> _cluster_name, conf_opts_context),
    do: {:conf_opts, [context: conf_opts_context]}

  def get_config_kv(@env_var_path_prefix <> _cluster_name, conf_path), do: {:conf, conf_path}
  def get_config_kv(@env_var_sa_prefix <> _cluster_name, "true"), do: {:use_sa, true}
  def get_config_kv(@env_var_sa_prefix <> _cluster_name, "false"), do: {:use_sa, false}

  def cluster_name(@env_var_context_prefix <> cluster_name), do: cluster_name
  def cluster_name(@env_var_path_prefix <> cluster_name), do: cluster_name
  def cluster_name(@env_var_sa_prefix <> cluster_name), do: cluster_name

  def env(), do: Map.take(System.get_env(), env_keys())

  @doc """
  export K8S_CLUSTER_CONF_SA_us_central=true
  export K8S_CLUSTER_CONF_PATH_us_east="east.yaml"
  export K8S_CLUSTER_CONF_CONTEXT_us_east="east"
  export K8S_CLUSTER_CONF_PATH_us_west="west.yaml"
  export K8S_CLUSTER_CONF_CONTEXT_dev="context-name"
  iex -S mix
  """
  def env_keys() do
    System.get_env()
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, @env_var_prefix))
  end
end
