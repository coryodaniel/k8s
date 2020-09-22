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

  alias K8s.Client.{Declarative, Imperative}
  alias K8s.Client.Runner.{Async, Base, Stream, Wait, Watch}

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

  @doc "alias of `K8s.Client.Imperative.get/1`"
  defdelegate get(resource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.get/2`"
  defdelegate get(api_version, kind), to: Imperative

  @doc "alias of `K8s.Client.Imperative.get/3`"
  defdelegate get(api_version, kind, opts), to: Imperative

  @doc "alias of `K8s.Client.Imperative.list/2`"
  defdelegate list(api_version, kind), to: Imperative

  @doc "alias of `K8s.Client.Imperative.list/3`"
  defdelegate list(api_version, kind, opts), to: Imperative

  @doc "alias of `K8s.Client.Imperative.create/1`"
  defdelegate create(resource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.create/4`"
  defdelegate create(api_version, kind, path_params, subresource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.create/2`"
  defdelegate create(resource, subresource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.patch/1`"
  defdelegate patch(resource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.patch/4`"
  defdelegate patch(api_version, kind, path_params, subresource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.patch/2`"
  defdelegate patch(resource, subresource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.update/1`"
  defdelegate update(resource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.update/4`"
  defdelegate update(api_version, kind, path_params, subresource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.update/2`"
  defdelegate update(resource, subresource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.delete/1`"
  defdelegate delete(resource), to: Imperative

  @doc "alias of `K8s.Client.Imperative.delete/3`"
  defdelegate delete(api_version, kind, opts), to: Imperative

  @doc "alias of `K8s.Client.Imperative.delete_all/2`"
  defdelegate delete_all(api_version, kind), to: Imperative

  @doc "alias of `K8s.Client.Imperative.delete_all/3`"
  defdelegate delete_all(api_version, kind, opts), to: Imperative

  @doc "alias of `K8s.Client.Declarative.apply/2`"
  defdelegate apply(resource, conn), to: Declarative
end
