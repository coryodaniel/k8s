defmodule K8s.Client do
  @moduledoc """
  Kubernetes API Client.

  Functions return `K8s.Operation`s that represent kubernetes operations.

  To run operations pass them to: `run/2`, or `run/3`

  When specifying kinds the format should either be in the literal kubernetes kind name (eg `"ServiceAccount"`)
  or the downcased version seen in kubectl (eg `"serviceaccount"`). A string or atom may be used.

  ## Examples
  ```elixir
  "Deployment", "deployment", :Deployment, :deployment
  "ServiceAccount", "serviceaccount", :ServiceAccount, :serviceaccount
  "HorizontalPodAutoscaler", "horizontalpodautoscaler", :HorizontalPodAutoscaler, :horizontalpodautoscaler
  ```

  `http_opts` to `K8s.Client.Runner` modules are `K8s.Client.HTTPProvider` HTTP options.
  """

  @type path_param :: {:name, String.t()} | {:namespace, binary() | :all}
  @type path_params :: [path_param]

  @mgmt_param_defaults %{
    field_manager: "elixir",
    force: true
  }

  alias K8s.Client.Runner.StreamTo
  alias K8s.Operation
  alias K8s.Client.Runner.{Async, Base, Stream, Wait}

  defdelegate put_conn(operation, conn), to: Operation

  @doc "alias of `K8s.Client.Runner.Base.run/1`"
  defdelegate run(operation), to: Base

  @doc "alias of `K8s.Client.Runner.Base.run/2`"
  defdelegate run(conn, operation), to: Base

  @doc "alias of `K8s.Client.Runner.Base.run/3`"
  defdelegate run(conn, operation, http_opts), to: Base
  @doc "alias of `K8s.Client.Runner.Async.run/3`"

  defdelegate async(conn, operations), to: Async, as: :run

  @doc "alias of `K8s.Client.Runner.Async.run/3`"
  defdelegate async(conn, operations, http_opts), to: Async, as: :run

  @doc "alias of `K8s.Client.Runner.Async.run/3`"
  defdelegate parallel(conn, operations, http_opts), to: Async, as: :run

  @doc "alias of `K8s.Client.Runner.Wait.run/2`"
  defdelegate wait_until(operation, wait_opts), to: Wait, as: :run

  @doc "alias of `K8s.Client.Runner.Wait.run/3`"
  defdelegate wait_until(conn, operation, wait_opts), to: Wait, as: :run

  @doc "alias of `K8s.Client.Runner.Stream.run/1`"
  defdelegate stream(operation), to: Stream, as: :run

  @doc "alias of `K8s.Client.Runner.Stream.run/2`"
  defdelegate stream(conn, operation), to: Stream, as: :run

  @doc "alias of `K8s.Client.Runner.Stream.run/3`"
  defdelegate stream(conn, operation, http_opts), to: Stream, as: :run

  @doc "alias of `K8s.Client.Runner.StreamTo.run/2`"
  defdelegate stream_to(operation, stream_to), to: StreamTo, as: :run

  @doc "alias of `K8s.Client.Runner.StreamTo.run/3`"
  defdelegate stream_to(conn, operation, stream_to), to: StreamTo, as: :run

  @doc "alias of `K8s.Client.Runner.StreamTo.run/4`"
  defdelegate stream_to(conn, operation, http_opts, stream_to), to: StreamTo, as: :run

  @doc """
  Returns a `PATCH` operation to server-side-apply the given resource.

  [K8s Docs](https://kubernetes.io/docs/reference/using-api/server-side-apply/):

  ## Examples
    Apply a deployment with management parameteres
      iex> deployment = K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
      ...> K8s.Client.apply(deployment, field_manager: "my-operator", force: true)
      %K8s.Operation{
        method: :patch,
        verb: :patch,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"],
        data: K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml"),
        query_params: [fieldManager: "my-operator", force: true],
        header_params: ["Content-Type": "application/apply-patch+yaml"],
      }
  """
  @spec apply(map(), keyword()) :: Operation.t()
  def apply(resource, mgmt_params \\ []) do
    field_manager = Keyword.get(mgmt_params, :field_manager, @mgmt_param_defaults[:field_manager])
    force = Keyword.get(mgmt_params, :force, @mgmt_param_defaults[:force])

    Operation.build(:patch, resource,
      field_manager: field_manager,
      force: force,
      patch_type: :apply
    )
  end

  @doc """
  Returns a `PATCH` operation to server-side-apply the given subresource given a resource's details and a subresource map.

  ## Examples

    Apply a status to a pod:
      iex> pod_with_status_subresource = K8s.Resource.from_file!("test/support/manifests/nginx-pod.yaml") |> Map.put("status", %{"message" => "some message"})
      ...> K8s.Client.apply("v1", "pods/status", [namespace: "default", name: "nginx"], pod_with_status_subresource, field_manager: "my-operator", force: true)
      %K8s.Operation{
        method: :patch,
        verb: :patch,
        api_version: "v1",
        name: "pods/status",
        path_params: [namespace: "default", name: "nginx"],
        data: K8s.Resource.from_file!("test/support/manifests/nginx-pod.yaml") |> Map.put("status", %{"message" => "some message"}),
        query_params: [fieldManager: "my-operator", force: true],
        header_params: ["Content-Type": "application/apply-patch+yaml"]
      }
  """
  @spec apply(binary, Operation.name_t(), Keyword.t(), map(), keyword()) :: Operation.t()
  def apply(
        api_version,
        kind,
        path_params,
        subresource,
        mgmt_params \\ []
      ) do
    field_manager = Keyword.get(mgmt_params, :field_manager, @mgmt_param_defaults[:field_manager])
    force = Keyword.get(mgmt_params, :force, @mgmt_param_defaults[:force])

    Operation.build(:patch, api_version, kind, path_params, subresource,
      field_manager: field_manager,
      force: force,
      patch_type: :apply
    )
  end

  @doc """
  Returns a `GET` operation for a resource given a Kubernetes manifest. May be a partial manifest as long as it contains:

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

    Get the nginx deployment in the default namespace by passing the kind as atom.
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
  @spec get(binary, Operation.name_t(), path_params | nil) :: Operation.t()
  def get(api_version, kind, path_params \\ []),
    do: Operation.build(:get, api_version, kind, path_params)

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
  @spec list(binary, Operation.name_t(), path_params | nil) :: Operation.t()
  def list(api_version, kind, path_params \\ [])

  def list(api_version, kind, namespace: :all),
    do: Operation.build(:list_all_namespaces, api_version, kind, [])

  def list(api_version, kind, path_params),
    do: Operation.build(:list, api_version, kind, path_params)

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
  @spec watch(binary, Operation.name_t(), path_params | nil) :: Operation.t()
  def watch(api_version, kind, path_params \\ [])

  def watch(api_version, kind, namespace: :all),
    do: Operation.build(:watch_all_namespaces, api_version, kind, [])

  def watch(api_version, kind, path_params),
    do: Operation.build(:watch, api_version, kind, path_params)

  @doc """
  Returns a `POST` `K8s.Operation` to create the given resource.

  ## Examples

      iex>  deployment = K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
      ...> K8s.Client.create(deployment)
      %K8s.Operation{
        method: :post,
        path_params: [namespace: "test", name: "nginx"],
        verb: :create,
        api_version: "apps/v1",
        name: "Deployment",
        data: K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
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

  def create(
        %{
          "apiVersion" => api_version,
          "kind" => kind,
          "metadata" => %{"namespace" => ns, "generateName" => _}
        } = resource
      ) do
    Operation.build(:create, api_version, kind, [namespace: ns], resource)
  end

  # Support for creating resources that are cluster-scoped, like Namespaces.
  def create(
        %{"apiVersion" => api_version, "kind" => kind, "metadata" => %{"name" => name}} = resource
      ) do
    Operation.build(:create, api_version, kind, [name: name], resource)
  end

  def create(
        %{"apiVersion" => api_version, "kind" => kind, "metadata" => %{"generateName" => _}} =
          resource
      ) do
    Operation.build(:create, api_version, kind, [], resource)
  end

  @doc """
  Returns a `POST` `K8s.Operation` to create the given subresource.

  Used for creating subresources like `Scale` or `Eviction`.

  ## Examples

  Evicting a pod
      iex> eviction = K8s.Resource.from_file!("test/support/manifests/eviction-policy.yaml")
      ...>  K8s.Client.create("v1", "pods/eviction", [namespace: "default", name: "nginx"], eviction)
      %K8s.Operation{
        api_version: "v1",
        method: :post,
        name: "pods/eviction",
        path_params: [namespace: "default", name: "nginx"],
        verb: :create,
        data: K8s.Resource.from_file!("test/support/manifests/eviction-policy.yaml")
      }
  """
  @spec create(binary, Operation.name_t(), Keyword.t(), map()) :: Operation.t()
  def create(api_version, kind, path_params, subresource),
    do: Operation.build(:create, api_version, kind, path_params, subresource)

  @doc """
  Returns a `POST` `K8s.Operation` to create the given subresource.

  Used for creating subresources like `Scale` or `Eviction`.

  ## Examples

  Evicting a pod
      iex> pod = K8s.Resource.from_file!("test/support/manifests/nginx-pod.yaml")
      ...> eviction = K8s.Resource.from_file!("test/support/manifests/eviction-policy.yaml")
      ...> K8s.Client.create(pod, eviction)
      %K8s.Operation{
        api_version: "v1",
        data: K8s.Resource.from_file!("test/support/manifests/eviction-policy.yaml"),
        method: :post, name: {"Pod", "Eviction"},
        path_params: [namespace: "default", name: "nginx"],
        verb: :create
      }
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

      iex>  deployment = K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
      ...> K8s.Client.patch(deployment)
      %K8s.Operation{
        method: :patch,
        verb: :patch,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"],
        data: K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml"),
        header_params: ["Content-Type": "application/merge-patch+json"]
      }
  """
  @spec patch(map()) :: Operation.t()
  def patch(%{} = resource),
    do: Operation.build(:patch, resource, patch_type: :merge)

  @spec patch(map(), patch_type_or_resource :: Operation.patch_type() | map()) :: Operation.t()
  def patch(%{} = resource, patch_type) when is_atom(patch_type),
    do: Operation.build(:patch, resource, patch_type: patch_type)

  def patch(%{} = resource, subresource) when is_map(resource),
    do: patch(resource, subresource, :merge)

  @doc """
  Returns a `PATCH` operation to patch the given subresource given a resource's details and a subresource map.
  """
  @spec patch(
          binary,
          Operation.name_t(),
          Keyword.t(),
          map(),
          patch_type :: Operation.patch_type()
        ) :: Operation.t()
  def patch(api_version, kind, path_params, subresource, patch_type \\ :merge),
    do:
      Operation.build(:patch, api_version, kind, path_params, subresource, patch_type: patch_type)

  @doc """
  Returns a `PATCH` operation to patch the given subresource given a resource map and a subresource map.
  """
  @spec patch(map(), map(), patch_type :: Operation.patch_type()) :: Operation.t()
  def patch(
        %{
          "apiVersion" => api_version,
          "kind" => kind,
          "metadata" => %{"namespace" => ns, "name" => name}
        },
        %{"kind" => subkind} = subresource,
        patch_type
      ) do
    Operation.build(
      :patch,
      api_version,
      {kind, subkind},
      [namespace: ns, name: name],
      subresource,
      patch_type: patch_type
    )
  end

  @doc """
  Returns a `PUT` operation to replace/update the given resource.

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  > Replacing a resource object will update the resource by replacing the existing spec with the provided one. For read-then-write operations this is safe because an optimistic lock failure will occur if the resource was modified between the read and write. Note: The ResourceStatus will be ignored by the system and will not be updated. To update the status, one must invoke the specific status update operation.
  > Note: Replacing a resource object may not result immediately in changes being propagated to downstream objects. For instance replacing a ConfigMap or Secret resource will not result in all Pods seeing the changes unless the Pods are restarted out of band.

  ## Examples

      iex>  deployment = K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
      ...> K8s.Client.update(deployment)
      %K8s.Operation{
        method: :put,
        verb: :update,
        api_version: "apps/v1",
        name: "Deployment",
        path_params: [namespace: "test", name: "nginx"],
        data: K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
      }
  """
  @spec update(map()) :: Operation.t()
  def update(%{} = resource), do: Operation.build(:update, resource)

  @doc """
  Returns a `PUT` operation to replace/update the given subresource given a resource's details and a subresource map.

  Used for updating subresources like `Scale` or `Status`.

  ## Examples

    Scaling a deployment
      iex> scale = K8s.Resource.from_file!("test/support/manifests/scale-replicas.yaml")
      ...>  K8s.Client.update("apps/v1", "deployments/scale", [namespace: "default", name: "nginx"], scale)
      %K8s.Operation{
        api_version: "apps/v1",
        data: K8s.Resource.from_file!("test/support/manifests/scale-replicas.yaml"),
        method: :put,
        name: "deployments/scale",
        path_params: [namespace: "default", name: "nginx"],
        verb: :update
      }
  """
  @spec update(binary, Operation.name_t(), Keyword.t(), map()) :: Operation.t()
  def update(api_version, kind, path_params, subresource),
    do: Operation.build(:update, api_version, kind, path_params, subresource)

  @doc """
  Returns a `PUT` operation to replace/update the given subresource given a resource map and a subresource map.

  Used for updating subresources like `Scale` or `Status`.

  ## Examples
    Scaling a deployment:
      iex> deployment = K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
      ...> scale = K8s.Resource.from_file!("test/support/manifests/scale-replicas.yaml")
      ...> K8s.Client.update(deployment, scale)
      %K8s.Operation{
        api_version: "apps/v1",
        method: :put,
        path_params: [namespace: "test", name: "nginx"],
        verb: :update,
        data: K8s.Resource.from_file!("test/support/manifests/scale-replicas.yaml"),
        name: {"Deployment", "Scale"}
      }
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

      iex> deployment = K8s.Resource.from_file!("test/support/manifests/nginx-deployment.yaml")
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
  @spec delete(binary, Operation.name_t(), path_params | nil) :: Operation.t()
  def delete(api_version, kind, path_params),
    do: Operation.build(:delete, api_version, kind, path_params)

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

  @doc """
  Returns a `CONNECT` operation for a pods/exec resource by version, kind/resource type, name, and optionally namespace.

  [K8s Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/):

  ## Examples
    connect to the nginx deployment in the test namespace:
      iex> K8s.Client.connect("apps/v1", "pods/exec", [namespace: "test", name: "nginx"], command: "ls")
      %K8s.Operation{
        method: :post,
        verb: :connect,
        api_version: "apps/v1",
        name: "pods/exec",
        path_params: [namespace: "test", name: "nginx"],
        query_params: [{:stdin, true}, {:stdout, true}, {:stderr, true}, {:tty, false}, {:command, "ls"}]
      }

  """
  @spec connect(binary(), binary() | atom(), [namespace: binary(), name: binary()], keyword()) ::
          Operation.t()
  def connect(api_version, kind, [namespace: namespace, name: name], opts \\ []) do
    Operation.build(:connect, api_version, kind, [namespace: namespace, name: name], nil, opts)
  end
end
