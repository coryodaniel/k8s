defmodule K8s.Client.HTTPProvider do
  @moduledoc """
  HTTPoison and Jason based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider
  require Logger

  @impl true
  def request(method, url, body, headers, http_opts) do
    :telemetry.span([:http, :request], %{method: method, url: url}, fn ->
      response = HTTPoison.request(method, url, body, headers, http_opts)

      case handle_response(response) do
        {:ok, result} ->
          {{:ok, result}, %{}}

        {:error, error} ->
          {{:error, error}, %{error: error}}
      end
    end)
  end

  @impl true
  def stream(method, url, body, headers, http_opts) do
    {:ok, create_stream(method, url, body, headers, http_opts)}
  end

  defp create_stream(method, url, body, headers, http_opts) do
    Stream.resource(
      fn ->
        case request(method, url, body, headers, Keyword.put(http_opts, :stream_to, self())) do
          {:ok, resp} -> %{resp: %HTTPoison.AsyncResponse{id: resp}}
          {:error, error} -> {:error, error}
        end
      end,
      fn
        :halt ->
          {:halt, nil}

        {:error, error} ->
          {[{:error, error}], :halt}

        state ->
          receive do
            %HTTPoison.AsyncEnd{} ->
              {:halt, nil}

            %HTTPoison.AsyncHeaders{headers: headers} ->
              HTTPoison.stream_next(state.resp)
              {[{:headers, headers}], state}

            %HTTPoison.AsyncStatus{code: status} ->
              HTTPoison.stream_next(state.resp)
              {[{:status, status}], state}

            %HTTPoison.AsyncChunk{chunk: chunk} ->
              HTTPoison.stream_next(state.resp)
              {[{:data, chunk}], state}

            %HTTPoison.Error{reason: {:closed, :timeout}} ->
              HTTPoison.stream_next(state.resp)
              {[{:error, {:closed, :timeout}}], state}

            other ->
              Logger.error(
                "HTTPoison request received unexpected message.",
                library: :k8s,
                message: other
              )

              # ignore other messages and continue
              {:halt, nil}
          end
      end,
      fn _state -> :ok end
    )
  end

  defp handle_response({:error, %HTTPoison.Error{} = err}),
    do: {:error, K8s.Client.HTTPError.new(message: err.reason, adapter_specific_error: err)}

  defp handle_response({:ok, %HTTPoison.AsyncResponse{id: ref}}), do: {:ok, ref}

  defp handle_response({:ok, resp}) do
    case resp do
      %HTTPoison.Response{status_code: code, body: body, headers: headers}
      when code in 200..299 ->
        content_type = get_content_type(headers)
        {:ok, decode(body, content_type)}

      %HTTPoison.Response{status_code: code} = err
      when code in 400..599 ->
        handle_error(err)
    end
  end

  @spec handle_error(HTTPoison.Response.t()) ::
          {:error, K8s.Client.APIError.t() | K8s.Client.HTTPError.t()}
  defp handle_error(%HTTPoison.Response{status_code: code, body: body, headers: headers} = resp) do
    case get_content_type(headers) do
      "application/json" = content_type ->
        body |> decode(content_type) |> K8s.Client.APIError.from_kubernetes_error()

      _other ->
        {:error,
         K8s.Client.HTTPError.new(
           message: "HTTP Error #{code}",
           adapter_specific_error: resp
         )}
    end
  end

  @spec decode(binary, binary) :: map | list | nil
  defp decode(body, "text/plain"), do: body

  defp decode(body, _default_json_decoder) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end

  @spec get_content_type(keyword()) :: binary | nil
  defp get_content_type(headers) do
    case List.keyfind(headers, "Content-Type", 0) do
      {_key, content_type} -> content_type
      _ -> nil
    end
  end
end
