defmodule K8s.Client do
  @moduledoc """
  Kubernetes API Client.

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
  alias K8s.Client.Runner.{Async, Base, Stream, Wait, Watch, PodExec}

  @doc "alias of `K8s.Client.Runner.Base.run/2`"
  defdelegate run(operation, conn), to: Base

  @doc "alias of `K8s.Client.Runner.Base.run/3`"
  defdelegate run(operation, conn, opts), to: Base

  @doc "alias of `K8s.Client.Runner.Base.run/4`"
  defdelegate run(operation, conn, resource, opts), to: Base

  @doc "alias of `K8s.Client.Runner.Async.run/3`"
  defdelegate async(operations, conn), to: Async, as: :run

  @doc "alias of `K8s.Client.Runner.Async.run/3`"
  defdelegate parallel(operations, conn, opts), to: Async, as: :run

  @doc "alias of `K8s.Client.Runner.Async.run/3`"
  defdelegate async(operations, conn, opts), to: Async, as: :run

  @doc "alias of `K8s.Client.Runner.Wait.run/3`"
  defdelegate wait_until(operation, conn, opts), to: Wait, as: :run

  @doc "alias of `K8s.Client.Runner.Watch.run/3`"
  defdelegate watch(operation, conn, opts), to: Watch, as: :run

  @doc "alias of `K8s.Client.Runner.Watch.run/4`"
  defdelegate watch(operation, conn, rv, opts), to: Watch, as: :run

  @doc "alias of `K8s.Client.Runner.Stream.run/2`"
  defdelegate stream(operation, conn), to: Stream, as: :run

  @doc "alias of `K8s.Client.Runner.Stream.run/3`"
  defdelegate stream(operation, conn, opts), to: Stream, as: :run

  @doc "alias of `K8s.Client.Runner.PodExec.run/3`"
  defdelegate exec(operation, cluster_name, opts), to: PodExec, as: :run

  @doc """
  Returns a `GET` operation for a resource given a manifest. May be a partial manifest as long as it contains:

    * apiVersion
    * kind
    * metadata.name
    * metadata.namespace (if applicable)

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Get will retrieve a specific resource object by name.

  ## Examples
    Getting a pod

      iex> pod = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
      ...>   "spec" => %{"containers" => %{"image" => "nginx"}}
      ...> }
      ...> K8s.Client.get(pod)
      %K8s.Operation{
        method: :get,
        verb: :get,
        api_version: "v1",
        name: "Pod",
        path_params: [namespace: "test", name: "nginx-pod"],
      }
  """
  @spec get(map()) :: Operation.t()
  def get(%{} = resource), do: Operation.build(:get, resource)

  @doc """
  Returns a `GET` operation for a resource by version, kind/resource type, name, and optionally namespace.

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Get will retrieve a specific resource object by name.

  ## Examples
    Get the nginx deployment in the default namespace:
      iex> K8s.Client.get("apps/v1", "Deployment", namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :get,
        verb: :get,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"]
      }

    Get the nginx deployment in the default namespace:
      iex> K8s.Client.get("apps/v1", :deployment, namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :get,
        verb: :get,
        api_version: "apps/v1",
        name: :deployment,
        path_params: [namespace: "test", name: "nginx"]}

    Get the nginx deployment's status:
      iex> K8s.Client.get("apps/v1", "deployments/status", namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :get,
        verb: :get,
        api_version: "apps/v1",
        name: "deployments/status",
        path_params: [namespace: "test", name: "nginx"]}

    Get the nginx deployment's scale:
      iex> K8s.Client.get("v1", "deployments/scale", namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :get,
        verb: :get,
        api_version: "v1",
        name: "deployments/scale",
        path_params: [namespace: "test", name: "nginx"]}

  """
  @spec get(binary, binary | atom, options | nil) :: Operation.t()
  def get(api_version, kind, opts \\ []), do: Operation.build(:get, api_version, kind, opts)

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
        verb: :list,
        api_version: "v1",
        name: "Pod",
        path_params: [namespace: "default"]
      }

      iex> K8s.Client.list("apps/v1", "Deployment", namespace: :all)
      %K8s.Operation{
        method: :get,
        verb: :list_all_namespaces,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: []
      }

  """
  @spec list(binary, binary | atom, options | nil) :: Operation.t()
  def list(api_version, kind, opts \\ [])

  def list(api_version, kind, namespace: :all),
    do: Operation.build(:list_all_namespaces, api_version, kind, [])

  def list(api_version, kind, opts),
    do: Operation.build(:list, api_version, kind, opts)

  @doc """
  Returns a `POST` `K8s.Operation` to create the given resource.

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
        path_params: [namespace: "test", name: "nginx"],
        verb: :create,
        api_version: "apps/v1",
        name: "Deployment",
        data: %{
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
        %{
          "apiVersion" => api_version,
          "kind" => kind,
          "metadata" => %{"namespace" => ns, "name" => name}
        } = resource
      ) do
    Operation.build(:create, api_version, kind, [namespace: ns, name: name], resource)
  end

  # Support for creating resources that are cluster-scoped, like Namespaces.
  def create(
        %{"apiVersion" => api_version, "kind" => kind, "metadata" => %{"name" => name}} = resource
      ) do
    Operation.build(:create, api_version, kind, [name: name], resource)
  end

  @doc """
  Returns a `POST` `K8s.Operation` to create the given subresource.

  Used for creating subresources like `Scale` or `Eviction`.

  ## Examples

  Eviction a pod
      iex> eviction = %{
      ...> "apiVersion" => "policy/v1beta1",
      ...>     "kind" => "Eviction",
      ...>    "metadata" => %{
      ...>      "name" => "nginx",
      ...>      "namespace" => "default"
      ...>    }
      ...>  }
      ...>  K8s.Client.create("v1", "pods/eviction", [namespace: "default", name: "nginx"], eviction)
      %K8s.Operation{api_version: "v1", data: %{"apiVersion" => "policy/v1beta1", "kind" => "Eviction", "metadata" => %{"name" => "nginx", "namespace" => "default"}}, method: :post, name: "pods/eviction", path_params: [namespace: "default", name: "nginx"], verb: :create}
  """
  @spec create(binary, binary | atom, Keyword.t(), map()) :: Operation.t()
  def create(api_version, kind, path_params, subresource),
    do: Operation.build(:create, api_version, kind, path_params, subresource)

  @doc """
  Returns a `POST` `K8s.Operation` to create the given subresource.

  Used for creating subresources like `Scale` or `Eviction`.

  ## Examples

  Eviction a pod
      iex> pod = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{
      ...>      "name" => "nginx",
      ...>      "namespace" => "default"
      ...>    }
      ...> }
      ...> eviction = %{
      ...> "apiVersion" => "policy/v1beta1",
      ...>     "kind" => "Eviction",
      ...>    "metadata" => %{
      ...>      "name" => "nginx",
      ...>      "namespace" => "default"
      ...>    }
      ...>  }
      ...>  K8s.Client.create(pod, eviction)
      %K8s.Operation{api_version: "v1", data: %{"apiVersion" => "policy/v1beta1", "kind" => "Eviction", "metadata" => %{"name" => "nginx", "namespace" => "default"}}, method: :post, name: {"Pod", "Eviction"}, path_params: [namespace: "default", name: "nginx"], verb: :create}
  """
  @spec create(map(), map()) :: Operation.t()
  def create(
        %{
          "apiVersion" => api_version,
          "kind" => kind,
          "metadata" => %{"namespace" => ns, "name" => name}
        },
        %{"kind" => subkind} = subresource
      ) do
    Operation.build(
      :create,
      api_version,
      {kind, subkind},
      [namespace: ns, name: name],
      subresource
    )
  end

  # Support for creating resources that are cluster-scoped, like Namespaces.
  def create(
        %{"apiVersion" => api_version, "kind" => kind, "metadata" => %{"name" => name}},
        %{"kind" => subkind} = subresource
      ) do
    Operation.build(:create, api_version, {kind, subkind}, [name: name], subresource)
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
        verb: :patch,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"],
        data: %{
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
  def patch(%{} = resource), do: Operation.build(:patch, resource)

  @doc """
  Returns a `PATCH` operation to patch the given subresource given a resource's details and a subresource map.
  """
  @spec patch(binary, binary | atom, Keyword.t(), map()) :: Operation.t()
  def patch(api_version, kind, path_params, subresource),
    do: Operation.build(:patch, api_version, kind, path_params, subresource)

  @doc """
  Returns a `PATCH` operation to patch the given subresource given a resource map and a subresource map.
  """
  @spec patch(map(), map()) :: Operation.t()
  def patch(
        %{
          "apiVersion" => api_version,
          "kind" => kind,
          "metadata" => %{"namespace" => ns, "name" => name}
        },
        %{"kind" => subkind} = subresource
      ) do
    Operation.build(
      :patch,
      api_version,
      {kind, subkind},
      [namespace: ns, name: name],
      subresource
    )
  end

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
      ...> K8s.Client.update(deployment)
      %K8s.Operation{
        method: :put,
        verb: :update,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"],
        data: %{
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
  @spec update(map()) :: Operation.t()
  def update(%{} = resource), do: Operation.build(:update, resource)

  @doc """
  Returns a `PUT` operation to replace/update the given subresource given a resource's details and a subresource map.

  Used for updating subresources like `Scale` or `Status`.

  ## Examples

    Scaling a deployment
      iex> scale = %{
      ...>   "kind" => "Scale",
      ...>   "apiVersion" => "apps/v1beta1",
      ...>   "metadata" => %{
      ...>     "name" => "nginx",
      ...>     "namespace" => "default"
      ...>   },
      ...>   "spec" => %{
      ...>     "replicas" => 3
      ...>   }
      ...> }
      ...>  K8s.Client.update("apps/v1", "deployments/scale", [namespace: "default", name: "nginx"], scale)
      %K8s.Operation{api_version: "apps/v1", data: %{"apiVersion" => "apps/v1beta1", "kind" => "Scale", "metadata" => %{"name" => "nginx", "namespace" => "default"}, "spec" => %{"replicas" => 3}}, method: :put, name: "deployments/scale", path_params: [namespace: "default", name: "nginx"], verb: :update}
  """
  @spec update(binary, binary | atom, Keyword.t(), map()) :: Operation.t()
  def update(api_version, kind, path_params, subresource),
    do: Operation.build(:update, api_version, kind, path_params, subresource)

  @doc """
  Returns a `PUT` operation to replace/update the given subresource given a resource map and a subresource map.

  Used for updating subresources like `Scale` or `Status`.

  ## Examples
    Scaling a deployment:
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
      ...> scale = %{
      ...>   "kind" => "Scale",
      ...>   "apiVersion" => "apps/v1beta1",
      ...>   "metadata" => %{
      ...>      "name" => "nginx",
      ...>      "namespace" => "test"
      ...>   },
      ...>   "spec" => %{
      ...>     "replicas" => 3
      ...>   }
      ...> }
      ...> K8s.Client.update(deployment, scale)
      %K8s.Operation{api_version: "apps/v1", method: :put, path_params: [namespace: "test", name: "nginx"], verb: :update, data: %{"apiVersion" => "apps/v1beta1", "kind" => "Scale", "metadata" => %{"name" => "nginx", "namespace" => "test"}, "spec" => %{"replicas" => 3}}, name: {"Deployment", "Scale"}}
  """
  @spec update(map(), map()) :: Operation.t()
  def update(
        %{
          "apiVersion" => api_version,
          "kind" => kind,
          "metadata" => %{"namespace" => ns, "name" => name}
        },
        %{"kind" => subkind} = subresource
      ) do
    Operation.build(
      :update,
      api_version,
      {kind, subkind},
      [namespace: ns, name: name],
      subresource
    )
  end

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
        verb: :delete,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"]
      }

  """
  @spec delete(map()) :: Operation.t()
  def delete(%{} = resource), do: Operation.build(:delete, resource)

  @doc """
  Returns a `DELETE` operation for a resource by version, kind, name, and optionally namespace.

  ## Examples

      iex> K8s.Client.delete("apps/v1", "Deployment", namespace: "test", name: "nginx")
      %K8s.Operation{
        method: :delete,
        verb: :delete,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"]
      }

  """
  @spec delete(binary, binary | atom, options | nil) :: Operation.t()
  def delete(api_version, kind, opts), do: Operation.build(:delete, api_version, kind, opts)

  @doc """
  Returns a `DELETE` collection operation for all instances of a cluster scoped resource kind.

  ## Examples

      iex> K8s.Client.delete_all("extensions/v1beta1", "PodSecurityPolicy")
      %K8s.Operation{
        method: :delete,
        verb: :deletecollection,
        api_version: "extensions/v1beta1",
        name: "PodSecurityPolicy",
        path_params: []
      }

      iex> K8s.Client.delete_all("storage.k8s.io/v1", "StorageClass")
      %K8s.Operation{
        method: :delete,
        verb: :deletecollection,
        api_version: "storage.k8s.io/v1",
        name: "StorageClass",
        path_params: []
      }
  """
  @spec delete_all(binary(), binary() | atom()) :: Operation.t()
  def delete_all(api_version, kind) do
    Operation.build(:deletecollection, api_version, kind, [])
  end

  @doc """
  Returns a `DELETE` collection operation for all instances of a resource kind in a specific namespace.

  ## Examples

      iex> K8s.Client.delete_all("apps/v1beta1", "ControllerRevision", namespace: "default")
      %K8s.Operation{
        method: :delete,
        verb: :deletecollection,
        api_version: "apps/v1beta1",
        name: "ControllerRevision",
        path_params: [namespace: "default"]
      }

      iex> K8s.Client.delete_all("apps/v1", "Deployment", namespace: "staging")
      %K8s.Operation{
        method: :delete,
        verb: :deletecollection,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "staging"]
      }
  """
  @spec delete_all(binary(), binary() | atom(), namespace: binary()) :: Operation.t()
  def delete_all(api_version, kind, namespace: namespace) do
    Operation.build(:deletecollection, api_version, kind, namespace: namespace)
  end
end
