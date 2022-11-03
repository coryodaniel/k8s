defmodule K8s.Client.Runner.PodExec do
  @moduledoc """
  Exec functionality for `K8s.Client`.
  """

  alias K8s.Operation
  alias K8s.Conn.RequestOptions
  alias K8s.Discovery
  require Logger

  @doc """
  Execute a command in a Pod.

  ## Example

  Running the `nginx -t` command inside a nginx pod without only one container and stream back the result to self():

  ```elixir
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")
  op = K8s.Client.create(%{"apiVersion" => "v1", "kind" => "pods/exec", "metadata" => %{"namespace" => "default", "name" => "nginx-76d6c9b8c-sq56w"}})
  exec_opts = [command: ["/bin/sh", "-c", "nginx -t"], stdin: true, stderr: true, stdout: true, tty: true, stream_to: self()]
  {:ok, pid} = K8s.Client.Runner.PodExec.run(conn, op, exec_opts)
  ```

  Running the `gem list` command inside a nginx pod specifying the fluentd container and stream back the result to self():

  ```elixir
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")
  op = K8s.Client.create(%{"apiVersion" => "v1", "kind" => "pods/exec", "metadata" => %{"namespace" => "default", "name" => "nginx-76d6c9b8c-sq56w"}})
  exec_opts = [command: ["/bin/sh", "-c", "gem list"], container: "fluentd", stdin: true, stderr: true, stdout: true, tty: true, stream_to: self()]
  {:ok, pid} = K8s.Client.Runner.PodExec.run(conn, op, exec_opts)
  ```

  opts defaults are [stdin: true, stderr: true, stdout: true, tty: true, stream_to: self()]

  """
  @spec run(Conn.t(), Operation.t(), keyword(atom())) ::
          {:ok, Pid.t()} | {:error, binary()}
  def run(conn, %Operation{name: "pods/exec"} = operation, opts) when is_list(opts) do
    Process.flag(:trap_exit, true)

    with {:ok, opts} <- process_opts(opts),
         {:ok, base_url} <- Discovery.url_for(conn, operation),
         {:ok, request_options} <- RequestOptions.generate(conn) do
      url = "#{base_url}?#{query_param_builder(opts)}"

      ## headers for websocket connection to k8s API
      headers =
        request_options.headers ++ [{"Accept", "*/*"}, {"Content-Type", "application/json"}]

      cacerts = Keyword.get(request_options.ssl_options, :cacerts)

      K8s.websocket_provider().request(
        url,
        false,
        request_options.ssl_options,
        cacerts,
        headers,
        opts
      )
    else
      {:error, message} -> {:error, message}
      error -> {:error, inspect(error)}
    end
  end

  def run(_, _, _), do: {:error, :unsupported_operation}

  defp process_opts(opts) do
    default = [stream_to: self(), stdin: true, stdout: true, stderr: true, tty: true]
    processed = Keyword.merge(default, opts)
    # check for command
    case Keyword.get(processed, :command) do
      nil -> {:error, ":command is required"}
      _ -> {:ok, processed}
    end
  end

  @doc false
  defp query_param_builder(params) do
    # do not need this in the query params
    Keyword.drop(params, [:stream_to])
    |> Enum.map(fn {k, v} ->
      case k do
        :command -> command_builder(v, []) |> Enum.join("&")
        _ -> "#{URI.encode_query(%{k => v})}"
      end
    end)
    |> Enum.join("&")
  end

  @doc false
  # k8s api can take multiple commands params per request
  defp command_builder([], acc), do: Enum.reverse(acc)

  @doc false
  defp command_builder([h | t], acc) do
    params = URI.encode_query(%{"command" => h})
    command_builder(t, ["#{params}" | acc])
  end
end
