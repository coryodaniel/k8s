defmodule K8s.Client do
  @moduledoc """
  An experimental k8s client.

  Functions return `K8s.Operation`s that represent kubernetes operations.

  To run operations pass them to: `run/2`, `run/3`, or `run/4`.

  When specifying kinds the format should either be in the literal kubernetes kind name (eg `"ServiceAccount"`)
  or the downcased version seen in kubectl (eg `"serviceaccount"`). A string or atom may be used.

  ## Examples
  ```elixir
  "Deployment", "deployment", :Deployment, :deployment
  "ServiceAccount", "serviceaccount", :ServiceAccount, :serviceaccount
  "HorizontalPodAutoscaler", "horizontalpodautoscaler", :HorizontalPodAutoscaler, :horizontalpodautoscaler
  ```

  `opts` to `K8s.Client.Runner` modules are HTTPoison HTTP option overrides.
  """

  @type option :: {:name, String.t()} | {:namespace, binary() | :all}
  @type options :: [option]

  alias K8s.Operation
  alias K8s.Client.Runner.{Async, Base, Wait, Watch}

  @doc "Alias of `create/1`"
  defdelegate post(resource), to: __MODULE__, as: :create

  @doc "Alias of `replace/1`"
  defdelegate update(resource), to: __MODULE__, as: :replace

  @doc "Alias of `replace/1`"
  defdelegate put(resource), to: __MODULE__, as: :replace

  @doc "alias of `K8s.Client.Runner.Base.run/2"
  defdelegate run(operation, cluster_name), to: Base

  @doc "alias of `K8s.Client.Runner.Base.run/3"
  defdelegate run(operation, cluster_name, opts), to: Base

  @doc "alias of `K8s.Client.Runner.Base.run/4"
  defdelegate run(operation, cluster_name, resource, opts), to: Base

  @doc "alias of `K8s.Client.Runner.Async.run/2"
  defdelegate async(operations, cluster_name), to: Async, as: :run

  @doc "alias of `K8s.Client.Runner.Wait.run/3"
  defdelegate wait_until(operation, cluster_name, opts), to: Wait, as: :run

  @doc "alias of `K8s.Client.Runner.Watch.run/3"
  defdelegate watch(operation, cluster_name, opts), to: Watch, as: :run

  @doc """
  Returns a `GET` operation for a resource given a manifest. May be a partial manifest as long as it contains:

    * apiVersion
    * kind
    * metadata.name
    * metadata.namespace (if applicable)

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Get will retrieve a specific resource object by name.

  ## Examples

      iex> pod = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
      ...>   "spec" => %{"containers" => %{"image" => "nginx"}}
      ...> }
      ...> K8s.Client.get(pod)
      %K8s.Operation{method: :get, id: "get/v1/pod/name/namespace", path_params: [namespace: "test", name: "nginx-pod"], resource: nil}
  """
  @spec get(map()) :: Operation.t()
  def get(resource = %{}), do: Operation.build(:get, resource)

  @doc """
  Returns a `GET` operation for a resource by version, kind, name, and optionally namespace.

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Get will retrieve a specific resource object by name.

  ## Examples

      iex> K8s.Client.get("apps/v1", "Deployment", namespace: "test", name: "nginx")
      %K8s.Operation{method: :get, resource: nil, id: "get/apps/v1/deployment/name/namespace", path_params: [namespace: "test", name: "nginx"]}

      iex> K8s.Client.get("apps/v1", :deployment, namespace: "test", name: "nginx")
      %K8s.Operation{method: :get, resource: nil, id: "get/apps/v1/deployment/name/namespace", path_params: [namespace: "test", name: "nginx"]}

  """
  @spec get(binary, binary, options | nil) :: Operation.t()
  def get(group_version, kind, opts \\ []), do: Operation.build(:get, group_version, kind, opts)

  @doc """
  Returns a `GET` operation to list all resources by version, kind, and namespace.

  Given the namespace `:all` as an atom, will perform a list across all namespaces.

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > List will retrieve all resource objects of a specific type within a namespace, and the results can be restricted to resources matching a selector query.
  > List All Namespaces: Like List but retrieves resources across all namespaces.

  ## Examples

      iex> K8s.Client.list("v1", "Pod", namespace: "default")
      %K8s.Operation{
        method: :get,
        path_params: [namespace: "default"],
        id: "list/v1/pod/namespace"
      }

      iex> K8s.Client.list("apps/v1", "Deployment", namespace: :all)
      %K8s.Operation{
        method: :get,
        path_params: [],
        id: "list_all_namespaces/apps/v1/deployment"
      }

  """
  @spec list(binary, binary, options | nil) :: Operation.t()
  def list(group_version, kind, opts \\ [])

  def list(group_version, kind, namespace: :all),
    do: Operation.build(:list_all_namespaces, group_version, kind, [])

  def list(group_version, kind, opts),
    do: Operation.build(:list, group_version, kind, opts)

  # def list(group_version, kind, namespace: namespace),
  #   do: Operation.build(:list, group_version, kind, namespace: namespace)

  @doc """
  Returns a `POST` operation to create the given resource.

  ## Examples

      iex>  deployment = %{
      ...>    "apiVersion" => "apps/v1",
      ...>    "kind" => "Deployment",
      ...>    "metadata" => %{
      ...>      "labels" => %{
      ...>        "app" => "nginx"
      ...>      },
      ...>      "name" => "nginx",
      ...>      "namespace" => "test"
      ...>    },
      ...>    "spec" => %{
      ...>      "replicas" => 2,
      ...>      "selector" => %{
      ...>        "matchLabels" => %{
      ...>          "app" => "nginx"
      ...>        }
      ...>      },
      ...>      "template" => %{
      ...>        "metadata" => %{
      ...>          "labels" => %{
      ...>            "app" => "nginx"
      ...>          }
      ...>        },
      ...>        "spec" => %{
      ...>          "containers" => %{
      ...>            "image" => "nginx",
      ...>            "name" => "nginx"
      ...>          }
      ...>        }
      ...>      }
      ...>    }
      ...>  }
      ...> K8s.Client.create(deployment)
      %K8s.Operation{
        method: :post,
        path_params: [namespace: "test"],
        id: "post/apps/v1/deployment/namespace",
        resource: %{
          "apiVersion" => "apps/v1",
          "kind" => "Deployment",
          "metadata" => %{
            "labels" => %{
              "app" => "nginx"
            },
            "name" => "nginx",
            "namespace" => "test"
          },
          "spec" => %{
            "replicas" => 2,
            "selector" => %{
                "matchLabels" => %{
                  "app" => "nginx"
                }
            },
            "template" => %{
              "metadata" => %{
                "labels" => %{
                  "app" => "nginx"
                }
              },
              "spec" => %{
                "containers" => %{
                  "image" => "nginx",
                  "name" => "nginx"
                }
              }
            }
          }
        }
      }
  """
  @spec create(map()) :: Operation.t()
  def create(
        resource = %{
          "apiVersion" => group_version,
          "kind" => kind,
          "metadata" => %{"namespace" => ns}
        }
      ) do
    Operation.build(:post, group_version, kind, [namespace: ns], resource)
  end

  # Support for creating resources that aren't namespaced... like a Namespace or other cluster-scoped resources.
  def create(
        resource = %{"apiVersion" => group_version, "kind" => kind, "metadata" => %{"name" => _}}
      ) do
    Operation.build(:post, group_version, kind, [], resource)
  end

  @doc """
  Returns a `PATCH` operation to patch the given resource.

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Patch will apply a change to a specific field. How the change is merged is defined per field. Lists may either be replaced or merged. Merging lists will not preserve ordering.
  > Patches will never cause optimistic locking failures, and the last write will win. Patches are recommended when the full state is not read before an update, or when failing on optimistic locking is undesirable. When patching complex types, arrays and maps, how the patch is applied is defined on a per-field basis and may either replace the field's current value, or merge the contents into the current value.

  ## Examples

      iex>  deployment = %{
      ...>    "apiVersion" => "apps/v1",
      ...>    "kind" => "Deployment",
      ...>    "metadata" => %{
      ...>      "labels" => %{
      ...>        "app" => "nginx"
      ...>      },
      ...>      "name" => "nginx",
      ...>      "namespace" => "test"
      ...>    },
      ...>    "spec" => %{
      ...>      "replicas" => 2,
      ...>      "selector" => %{
      ...>        "matchLabels" => %{
      ...>          "app" => "nginx"
      ...>        }
      ...>      },
      ...>      "template" => %{
      ...>        "metadata" => %{
      ...>          "labels" => %{
      ...>            "app" => "nginx"
      ...>          }
      ...>        },
      ...>        "spec" => %{
      ...>          "containers" => %{
      ...>            "image" => "nginx",
      ...>            "name" => "nginx"
      ...>          }
      ...>        }
      ...>      }
      ...>    }
      ...>  }
      ...> K8s.Client.patch(deployment)
      %K8s.Operation{
        method: :patch,
        path_params: [namespace: "test", name: "nginx"],
        id: "patch/apps/v1/deployment/name/namespace",
        resource: %{
          "apiVersion" => "apps/v1",
          "kind" => "Deployment",
          "metadata" => %{
            "labels" => %{
              "app" => "nginx"
            },
            "name" => "nginx",
            "namespace" => "test"
          },
          "spec" => %{
            "replicas" => 2,
            "selector" => %{
                "matchLabels" => %{
                  "app" => "nginx"
                }
            },
            "template" => %{
              "metadata" => %{
                "labels" => %{
                  "app" => "nginx"
                }
              },
              "spec" => %{
                "containers" => %{
                  "image" => "nginx",
                  "name" => "nginx"
                }
              }
            }
          }
        }
      }
  """
  @spec patch(map()) :: Operation.t()
  def patch(resource = %{}), do: Operation.build(:patch, resource)

  @doc """
  Returns a `PUT` operation to replace/update the given resource.

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Replacing a resource object will update the resource by replacing the existing spec with the provided one. For read-then-write operations this is safe because an optimistic lock failure will occur if the resource was modified between the read and write. Note: The ResourceStatus will be ignored by the system and will not be updated. To update the status, one must invoke the specific status update operation.
  > Note: Replacing a resource object may not result immediately in changes being propagated to downstream objects. For instance replacing a ConfigMap or Secret resource will not result in all Pods seeing the changes unless the Pods are restarted out of band.

  ## Examples

      iex>  deployment = %{
      ...>    "apiVersion" => "apps/v1",
      ...>    "kind" => "Deployment",
      ...>    "metadata" => %{
      ...>      "labels" => %{
      ...>        "app" => "nginx"
      ...>      },
      ...>      "name" => "nginx",
      ...>      "namespace" => "test"
      ...>    },
      ...>    "spec" => %{
      ...>      "replicas" => 2,
      ...>      "selector" => %{
      ...>        "matchLabels" => %{
      ...>          "app" => "nginx"
      ...>        }
      ...>      },
      ...>      "template" => %{
      ...>        "metadata" => %{
      ...>          "labels" => %{
      ...>            "app" => "nginx"
      ...>          }
      ...>        },
      ...>        "spec" => %{
      ...>          "containers" => %{
      ...>            "image" => "nginx",
      ...>            "name" => "nginx"
      ...>          }
      ...>        }
      ...>      }
      ...>    }
      ...>  }
      ...> K8s.Client.replace(deployment)
      %K8s.Operation{
        method: :put,
        path_params: [namespace: "test", name: "nginx"],
        id: "put/apps/v1/deployment/name/namespace",
        resource: %{
          "apiVersion" => "apps/v1",
          "kind" => "Deployment",
          "metadata" => %{
            "labels" => %{
              "app" => "nginx"
            },
            "name" => "nginx",
            "namespace" => "test"
          },
          "spec" => %{
            "replicas" => 2,
            "selector" => %{
                "matchLabels" => %{
                  "app" => "nginx"
                }
            },
            "template" => %{
              "metadata" => %{
                "labels" => %{
                  "app" => "nginx"
                }
              },
              "spec" => %{
                "containers" => %{
                  "image" => "nginx",
                  "name" => "nginx"
                }
              }
            }
          }
        }
      }
  """
  @spec replace(map()) :: Operation.t()
  def replace(resource = %{}), do: Operation.build(:put, resource)

  @doc """
  Returns a `DELETE` operation for a resource by manifest. May be a partial manifest as long as it contains:

  * apiVersion
  * kind
  * metadata.name
  * metadata.namespace (if applicable)

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Delete will delete a resource. Depending on the specific resource, child objects may or may not be garbage collected by the server. See notes on specific resource objects for details.

  ## Examples

      iex>  deployment = %{
      ...>    "apiVersion" => "apps/v1",
      ...>    "kind" => "Deployment",
      ...>    "metadata" => %{
      ...>      "labels" => %{
      ...>        "app" => "nginx"
      ...>      },
      ...>      "name" => "nginx",
      ...>      "namespace" => "test"
      ...>    },
      ...>    "spec" => %{
      ...>      "replicas" => 2,
      ...>      "selector" => %{
      ...>        "matchLabels" => %{
      ...>          "app" => "nginx"
      ...>        }
      ...>      },
      ...>      "template" => %{
      ...>        "metadata" => %{
      ...>          "labels" => %{
      ...>            "app" => "nginx"
      ...>          }
      ...>        },
      ...>        "spec" => %{
      ...>          "containers" => %{
      ...>            "image" => "nginx",
      ...>            "name" => "nginx"
      ...>          }
      ...>        }
      ...>      }
      ...>    }
      ...>  }
      ...> K8s.Client.delete(deployment)
      %K8s.Operation{
        method: :delete,
        path_params: [namespace: "test", name: "nginx"],
        id: "delete/apps/v1/deployment/name/namespace"
      }

  """
  @spec delete(map()) :: Operation.t()
  def delete(resource = %{}), do: Operation.build(:delete, resource)

  @doc """
  Returns a `DELETE` operation for a resource by version, kind, name, and optionally namespace.

  ## Examples

      iex> K8s.Client.delete("apps/v1", "Deployment", namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :delete,
        path_params: [namespace: "test", name: "nginx"],
        id: "delete/apps/v1/deployment/name/namespace"
      }

  """
  @spec delete(binary, binary, options | nil) :: Operation.t()
  def delete(group_version, kind, opts), do: Operation.build(:delete, group_version, kind, opts)

  @doc """
  Returns a `DELETE` collection operation for all instances of a cluster scoped resource kind.

  ## Examples

      iex> K8s.Client.delete_all("extensions/v1beta1", "PodSecurityPolicy")
      %K8s.Operation{
        method: :delete,
        path_params: [],
        id: "deletecollection/extensions/v1beta1/podsecuritypolicy"
      }

      iex> K8s.Client.delete_all("storage.k8s.io/v1", "StorageClass")
      %K8s.Operation{
        method: :delete,
        path_params: [],
        id: "deletecollection/storage.k8s.io/v1/storageclass"
      }
  """
  @spec delete_all(binary(), binary()) :: Operation.t()
  def delete_all(group_version, kind) do
    Operation.build(:deletecollection, group_version, kind, [])
  end

  @doc """
  Returns a `DELETE` collection operation for all instances of a resource kind in a specific namespace.

  ## Examples

      iex> K8s.Client.delete_all("apps/v1beta1", "ControllerRevision", namespace: "default")
      %K8s.Operation{
        method: :delete,
        path_params: [namespace: "default"],
        id: "deletecollection/apps/v1beta1/controllerrevision/namespace"
      }

      iex> K8s.Client.delete_all("apps/v1", "Deployment", namespace: "staging")
      %K8s.Operation{
        method: :delete,
        path_params: [namespace: "staging"],
        id: "deletecollection/apps/v1/deployment/namespace"
      }
  """
  @spec delete_all(binary(), binary(), namespace: binary()) :: Operation.t()
  def delete_all(group_version, kind, namespace: namespace) do
    Operation.build(:deletecollection, group_version, kind, namespace: namespace)
  end

  @doc """
  Returns a `GET` operation for a pod's logs given a manifest. May be a partial manifest as long as it contains:

    * apiVersion
    * kind
    * metadata.name
    * metadata.namespace

  ## Examples

      iex> pod = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
      ...>   "spec" => %{"containers" => %{"image" => "nginx"}}
      ...> }
      ...> K8s.Client.get_log(pod)
      %K8s.Operation{
        method: :get,
        path_params: [namespace: "test", name: "nginx-pod"],
        id: "get_log/v1/pod/name/namespace"
      }
  """
  @spec get_log(map()) :: Operation.t()
  def get_log(resource = %{}), do: Operation.build(:get_log, resource)

  @doc """
  Returns a `GET` operation for a pod's logs given a namespace and a pod name.

  ## Examples

      iex> K8s.Client.get_log("v1", "Pod", namespace: "test", name: "nginx-pod")
      %K8s.Operation{
        method: :get,
        path_params: [namespace: "test", name: "nginx-pod"],
        id: "get_log/v1/pod/name/namespace"
      }
  """
  @spec get_log(binary, binary, options) :: Operation.t()
  def get_log(group_version, kind, opts), do: Operation.build(:get_log, group_version, kind, opts)

  @doc """
  Returns a `GET` operation for a resource's status given a manifest. May be a partial manifest as long as it contains:

    * apiVersion
    * kind
    * metadata.name
    * metadata.namespace (if applicable)

  ## Examples

      iex> pod = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
      ...>   "spec" => %{"containers" => %{"image" => "nginx"}}
      ...> }
      ...> K8s.Client.get_status(pod)
      %K8s.Operation{
        method: :get,
        path_params: [namespace: "test", name: "nginx-pod"],
        id: "get_status/v1/pod/name/namespace"
      }
  """
  @spec get_status(map()) :: Operation.t()
  def get_status(resource = %{}), do: Operation.build(:get_status, resource)

  @doc """
  Returns a `GET` operation for a resource's status by version, kind, name, and optionally namespace.

  ## Examples

      iex> K8s.Client.get_status("apps/v1", "Deployment", namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :get,
        path_params: [namespace: "test", name: "nginx"],
        id: "get_status/apps/v1/deployment/name/namespace"
      }

  """
  @spec get_status(binary, binary, options | nil) :: Operation.t()
  def get_status(group_version, kind, opts \\ []),
    do: Operation.build(:get_status, group_version, kind, opts)

  @doc """
  Returns a `PATCH` operation for a resource's status given a manifest. May be a partial manifest as long as it contains:

    * apiVersion
    * kind
    * metadata.name
    * metadata.namespace (if applicable)

  ## Examples

      iex> pod = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
      ...>   "spec" => %{"containers" => %{"image" => "nginx"}}
      ...> }
      ...> K8s.Client.patch_status(pod)
      %K8s.Operation{
        method: :patch,
        resource: %{"apiVersion" => "v1", "kind" => "Pod", "metadata" => %{"name" => "nginx-pod", "namespace" => "test"}, "spec" => %{"containers" => %{"image" => "nginx"}}},
        id: "patch_status/v1/pod/name/namespace",
        path_params: [namespace: "test", name: "nginx-pod"]
      }
  """
  @spec patch_status(map()) :: Operation.t()
  def patch_status(resource = %{}), do: Operation.build(:patch_status, resource)

  @doc """
  Returns a `PATCH` operation for a resource's status by version, kind, name, and optionally namespace.

  ## Examples
      iex> K8s.Client.patch_status("apps/v1", "Deployment", namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :patch,
        resource: nil,
        id: "patch_status/apps/v1/deployment/name/namespace",
        path_params: [namespace: "test", name: "nginx"]
      }

  """
  @spec patch_status(binary, binary, options | nil) :: Operation.t()
  def patch_status(group_version, kind, opts \\ []),
    do: Operation.build(:patch_status, group_version, kind, opts)

  @doc """
  Returns a `PUT` operation for a resource's status given a manifest. May be a partial manifest as long as it contains:

    * apiVersion
    * kind
    * metadata.name
    * metadata.namespace (if applicable)

  ## Examples

      iex> pod = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
      ...>   "spec" => %{"containers" => %{"image" => "nginx"}}
      ...> }
      ...> K8s.Client.put_status(pod)
      %K8s.Operation{
        method: :put,
        id: "put_status/v1/pod/name/namespace",
        path_params: [namespace: "test", name: "nginx-pod"],
        resource: %{
          "apiVersion" => "v1",
          "kind" => "Pod",
          "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
          "spec" => %{"containers" => %{"image" => "nginx"}}
        }
      }
  """
  @spec put_status(map()) :: Operation.t()
  def put_status(resource = %{}), do: Operation.build(:put_status, resource)

  @doc """
  Returns a `PUT` operation for a resource's status by version, kind, name, and optionally namespace.

  ## Examples
      iex> K8s.Client.put_status("apps/v1", "Deployment", namespace: "test", name: "nginx")
      %K8s.Operation{
        resource: nil,
        id: "put_status/apps/v1/deployment/name/namespace",
        method: :put,
        path_params: [namespace: "test", name: "nginx"]
      }

  """
  @spec put_status(binary, binary, options | nil) :: Operation.t()
  def put_status(group_version, kind, opts \\ []),
    do: Operation.build(:put_status, group_version, kind, opts)
end
