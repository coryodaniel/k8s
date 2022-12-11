defmodule K8s.Client.Mint.HTTP do
  alias K8s.Client.Provider
  alias K8s.Client.HTTPError

  require Logger
  require Mint.HTTP

  @type t :: %__MODULE__{
          conn: Mint.HTTP.t(),
          request_ref: Mint.Types.request_ref() | nil
        }

  @typep request_response_t :: %{
           status: integer(),
           chunks: list(),
           headers: list()
         }

  defstruct [:conn, :request_ref]

  @spec request(
          method :: atom(),
          uri :: URI.t(),
          body :: binary,
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.response_t()
  def request(method, uri, body, headers, http_opts) do
    with {:ok, stream} <- stream(method, uri, body, headers, http_opts) do
      response =
        Enum.reduce_while(stream, %{chunks: [], status: nil, headers: []}, fn
          {:data, responses}, acc -> {:cont, Map.update!(acc, :chunks, &[responses | &1])}
          {:status, code}, acc -> {:cont, Map.put(acc, :status, code)}
          {:headers, headers}, acc -> {:cont, Map.update!(acc, :headers, &(&1 ++ headers))}
          {:error, error}, _acc -> {:halt, {:error, error}}
          _other, acc -> {:cont, acc}
        end)

      response
      |> Map.update!(:chunks, &Enum.reverse(&1))
      |> process_response()
    end
  end

  @spec stream(
          method :: atom(),
          uri :: URI.t(),
          body :: binary,
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.stream_response_t()
  def stream(method, uri, body, headers, http_opts) do
    transport_opts = Keyword.fetch!(http_opts, :ssl)
    method = String.upcase("#{method}")

    path =
      IO.iodata_to_binary([
        uri.path,
        if(uri.query, do: ["?" | uri.query], else: [])
      ])

    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)

    with {:ok, conn} <- connect(uri, transport_opts: transport_opts) do
      start_fn = fn -> start_request(conn, method, path, body, headers) end

      stream =
        start_fn
        |> create_stream()
        |> Stream.map(&map_responses/1)

      {:ok, stream}
    end
  end

  @spec connect(URI.t(), Keyword.t()) :: {:error, HTTPError.t()} | {:ok, Mint.HTTP.t()}
  def connect(uri, opts) do
    case Mint.HTTP.connect(
           String.to_atom(uri.scheme),
           uri.host,
           uri.port,
           opts
         ) do
      {:error, error}
      when is_exception(error, Mint.HTTPError) or
             is_exception(error, Mint.TransportError) ->
        {:error, HTTPError.new(message: error.reason, adapter_specific_error: error)}

      {:ok, conn} ->
        {:ok, conn}
    end
  end

  @spec start_request(Mint.HTTP.t(), binary(), binary(), binary(), list()) ::
          t() | {:error, t(), HTTPError.t()}
  defp start_request(conn, method, path, body, headers) do
    case Mint.HTTP.request(conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        struct!(__MODULE__, conn: conn, request_ref: request_ref)

      {:error, conn, error}
      when is_exception(error, Mint.HTTPError) or is_exception(error, Mint.TransportError) ->
        {:error, struct!(__MODULE__, conn: conn),
         HTTPError.new(message: error.reason, adapter_specific_error: error)}
    end
  end

  @spec create_stream(fun()) ::
          Enumerable.t(K8s.Client.Provider.stream_chunk_t())
  defp create_stream(start_fn) do
    Stream.resource(
      start_fn,
      &next_fun/1,
      fn state -> Mint.HTTP.close(state.conn) end
    )
  end

  @spec next_fun({:error, t(), HTTPError.t()}) :: {[HTTPError.t()], {:halt, t()}}
  defp next_fun({:error, state, error}), do: {[error], {:halt, state}}

  @spec next_fun({:halt, t()}) :: {:halt, t()}
  defp next_fun({:halt, state}), do: {:halt, state}

  defp next_fun(%{request_ref: request_ref} = state) do
    receive do
      message when Mint.HTTP.is_connection_message(state.conn, message) ->
        {:ok, conn, responses} = Mint.HTTP.stream(state.conn, message)
        next_state = struct!(state, conn: conn)

        next_state =
          if {:done, request_ref} == List.last(responses),
            do: {:halt, next_state},
            else: next_state

        {responses, next_state}

      _other ->
        {[], state}
    end
  end

  @spec process_response(request_response_t()) :: K8s.Client.Provider.response_t()
  defp process_response(%{status: status} = response) when status in 400..599 do
    %{chunks: chunks, headers: headers, status: status_code} = response

    case get_content_type(headers) do
      "application/json" = content_type ->
        chunks
        |> IO.iodata_to_binary()
        |> decode(content_type)
        |> K8s.Client.APIError.from_kubernetes_error()

      _other ->
        {:error, K8s.Client.HTTPError.new(message: "HTTP Error #{status_code}")}
    end
  end

  defp process_response(response) do
    content_type = get_content_type(response.headers)
    body = response.chunks |> IO.iodata_to_binary() |> decode(content_type)

    {:ok, body}
  end

  @spec get_content_type(keyword()) :: binary | nil
  defp get_content_type(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_key, content_type} -> content_type
      _ -> nil
    end
  end

  @spec decode(binary, binary) :: map | list | nil
  defp decode(body, "text/plain"), do: body

  defp decode(body, "application/json") do
    case Jason.decode(body) do
      {:ok, data} ->
        data

      {:error, error} ->
        Logger.error("The response body is supposed to be JSON but could not be decoded.",
          library: :k8s,
          error: error
        )

        nil
    end
  end

  @spec map_responses(
          {atom(), Mint.Types.request_ref()}
          | {atom(), Mint.Types.request_ref(), term()}
        ) :: atom() | {atom(), term()}
  defp map_responses({type, _ref}), do: type

  defp map_responses({type, _ref, data}), do: {type, data}
end
