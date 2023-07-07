defmodule K8s.Client.Runner.Wait do
  @moduledoc """
  Waiting functionality for `K8s.Client`.

  Note: This is built using repeated GET operations rather than using a [watch](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#watch-list-deployment-v1-apps) operation w/ `fieldSelector`.
  """

  alias K8s.{Conn, Operation}
  alias K8s.Client.Runner.{Base, Wait}
  alias K8s.Operation.Error

  @typedoc "A wait configuration"
  @type t :: %__MODULE__{
          timeout: pos_integer,
          sleep: pos_integer,
          eval: any | (any -> any),
          find: list(binary) | (any -> any),
          timeout_after: NaiveDateTime.t(),
          processor: (map(), map() -> {:ok, map} | {:error, Error.t()})
        }
  defstruct [:timeout, :sleep, :eval, :find, :timeout_after, :processor]

  @doc """
  Continually perform a GET based operation until a condition is met.

  ## Example

  This follow example will wait 60 seconds for the field `status.succeeded` to equal `1`.

  ```elixir
  op = K8s.Client.get("batch/v1", :job, namespace: "default", name: "sleep")
  opts = [find: ["status", "succeeded"], eval: 1, timeout: 60]
  {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
  resp = K8s.Client.Runner.Wait.run(conn, op, opts)
  ```
  """
  @spec run(Operation.t(), keyword()) ::
          {:ok, :deleted} | {:ok, map()} | {:error, :timeout | Error.t()}

  def run(%Operation{conn: %Conn{} = conn} = op, opts), do: run(conn, op, opts)

  @spec run(Conn.t(), Operation.t(), keyword()) ::
          {:ok, :deleted} | {:ok, map()} | {:error, :timeout | Error.t()}
  def run(%Conn{} = conn, %Operation{method: :get} = op, opts) do
    conditions =
      Wait
      |> struct(opts)
      |> process_opts()

    case conditions do
      {:ok, opts} -> run_operation(conn, op, opts)
      error -> error
    end
  end

  def run(%Conn{} = conn, %Operation{method: :delete} = op, opts) do
    case Base.run(conn, op) do
      {:ok, _} ->
        run(
          conn,
          struct(op, method: :get),
          Keyword.merge(opts,
            processor: &get_deleted_processor/2,
            find: &Function.identity/1,
            eval: :deleted
          )
        )

      error ->
        error
    end
  end

  def run(op, _, _),
    do:
      {:error,
       %Error{message: "Only HTTP GET and DELETE operations are supported. #{inspect(op)}"}}

  @spec get_deleted_processor(Conn.t(), Operation.t()) :: {:ok, :deleted} | {:error, :exists}
  defp get_deleted_processor(conn, op) do
    case Base.run(conn, op) do
      {:error, %K8s.Client.APIError{reason: "NotFound"}} -> {:ok, :deleted}
      {:ok, _} -> {:error, :exists}
    end
  end

  @spec process_opts(Wait.t() | map) :: {:error, Error.t()} | {:ok, map}
  defp process_opts(%Wait{eval: nil}), do: {:error, %Error{message: ":eval is required"}}
  defp process_opts(%Wait{find: nil}), do: {:error, %Error{message: ":find is required"}}

  defp process_opts(opts) when is_map(opts) do
    timeout = Map.get(opts, :timeout) || 30
    sleep = Map.get(opts, :sleep) || 1
    now = NaiveDateTime.utc_now()
    timeout_after = NaiveDateTime.add(now, timeout, :second)
    processor = Map.get(opts, :processor) || (&Base.run/2)

    processed =
      opts
      |> Map.put(:timeout, timeout)
      |> Map.put(:sleep, sleep * 1000)
      |> Map.put(:timeout_after, timeout_after)
      |> Map.put(:processor, processor)

    {:ok, processed}
  end

  @spec run_operation(Conn.t(), Operation.t(), Wait.t()) :: {:error, :timeout} | {:ok, any}
  defp run_operation(
         %Conn{} = conn,
         %Operation{} = op,
         %Wait{timeout_after: timeout_after} = opts
       ) do
    case timed_out?(timeout_after) do
      true -> {:error, :timeout}
      false -> evaluate_operation(conn, op, opts)
    end
  end

  @spec evaluate_operation(Conn.t(), Operation.t(), Wait.t()) :: {:error, :timeout} | {:ok, any}
  defp evaluate_operation(
         %Conn{} = conn,
         %Operation{} = op,
         %Wait{processor: processor, sleep: sleep, eval: eval, find: find} = opts
       ) do
    with {:ok, resp} <- processor.(conn, op),
         true <- satisfied?(resp, find, eval) do
      {:ok, resp}
    else
      _not_satisfied ->
        Process.sleep(sleep)
        run_operation(conn, op, opts)
    end
  end

  @spec satisfied?(map, function | list, any) :: boolean
  defp satisfied?(resp, find, eval) when is_list(find) do
    value = get_in(resp, find)
    compare(value, eval)
  end

  defp satisfied?(resp, find, eval) when is_function(find) do
    value = find.(resp)
    compare(value, eval)
  end

  @spec compare(any, any) :: boolean
  defp compare(value, eval) when not is_function(eval), do: value == eval
  defp compare(value, eval) when is_function(eval), do: eval.(value)

  @spec timed_out?(NaiveDateTime.t()) :: boolean
  defp timed_out?(timeout_after) do
    case NaiveDateTime.compare(NaiveDateTime.utc_now(), timeout_after) do
      :gt -> true
      _ -> false
    end
  end
end
