defmodule K8s.Client.Runner.Wait do
  @moduledoc """
  Waiting functionality for `K8s.Client`.

  Note: This is built using repeated GET operations rather than using a [watch](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#watch-list-deployment-v1-apps) operation w/ `fieldSelector`.
  """

  alias K8s.Operation
  alias K8s.Client.Runner.{Base, Wait}

  @typedoc "A wait configuration"
  @type t :: %__MODULE__{
          timeout: pos_integer,
          sleep: pos_integer,
          eval: any | (any -> any),
          find: list(binary) | (any -> any),
          timeout_after: NaiveDateTime.t(),
          processor: (map(), map() -> {:ok, map} | {:error, binary})
        }
  defstruct [:timeout, :sleep, :eval, :find, :timeout_after, :processor]

  @doc """
  Continually perform a GET based operation until a condition is met.

  ## Example

  Checking the number of job completions:

  ```elixir
  op = K8s.Client.get("batch/v1", :job, namespace: "default", name: "sleep")
  conf = K8s.Conf.from_file("~/.kube/config")

  opts = [find: ["status", "succeeded"], eval: 1, timeout: 60]
  resp = K8s.Client.Runner.Wait.run(op, conf, opts)
  ```
  """
  @spec run(Operation.t(), map(), keyword(atom())) ::
          {:ok, map()} | {:error, binary()}
  def run(op = %Operation{method: :get}, conf, opts) do
    conditions =
      Wait
      |> struct(opts)
      |> process_opts()

    case conditions do
      {:ok, opts} -> run_operation(op, conf, opts)
      error -> error
    end
  end

  def run(op, _, _), do: {:error, "Only HTTP GET operations are supported. #{inspect(op)}"}

  defp process_opts(%Wait{eval: nil}), do: {:error, ":eval is required"}
  defp process_opts(%Wait{find: nil}), do: {:error, ":find is required"}

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

  defp run_operation(op, conf, opts = %Wait{timeout_after: timeout_after}) do
    case timed_out?(timeout_after) do
      true -> {:error, :timeout}
      false -> evaluate_operation(op, conf, opts)
    end
  end

  defp evaluate_operation(
         op,
         conf,
         opts = %Wait{processor: processor, sleep: sleep, eval: eval, find: find}
       ) do
    with {:ok, resp} <- processor.(op, conf),
         true <- satisfied?(resp, find, eval) do
      {:ok, resp}
    else
      _not_satisfied ->
        Process.sleep(sleep)
        run_operation(op, conf, opts)
    end
  end

  defp satisfied?(resp = %{}, find, eval) when is_list(find) do
    value = get_in(resp, find)
    compare(value, eval)
  end

  defp satisfied?(resp = %{}, find, eval) when is_function(find) do
    value = find.(resp)
    compare(value, eval)
  end

  defp compare(value, eval) when not is_function(eval), do: value == eval
  defp compare(value, eval) when is_function(eval), do: eval.(value)

  defp timed_out?(timeout_after) do
    case NaiveDateTime.compare(NaiveDateTime.utc_now(), timeout_after) do
      :gt -> true
      _ -> false
    end
  end
end
