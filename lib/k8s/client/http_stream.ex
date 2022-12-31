defmodule K8s.Client.HTTPStream do
  @moduledoc """
  Helper functions for HTTP stream processing.
  """
  require Logger

  alias K8s.Client.Provider

  @type to_lines_t :: %{remainder: binary()}

  @spec transform_to_lines(Enumerable.t(Provider.http_chunk_t())) ::
          Enumerable.t(Provider.http_chunk_t() | {:line, binary()})
  def transform_to_lines(stream) do
    stream
    |> Stream.transform(%{remainder: ""}, fn
      {:data, chunk}, state ->
        chunks_to_lines(chunk, state)

      :done, %{remainder: ""} = state ->
        {[:done], state}

      :done, state ->
        {[{:line, state.remainder}, :done], state}

      other, state ->
        {[other], state}
    end)
  end

  @spec chunks_to_lines(binary(), to_lines_t()) :: {[{:line, binary()}], to_lines_t()}
  defp chunks_to_lines(chunk, state) do
    {remainder, whole_lines} =
      (state.remainder <> chunk)
      |> String.split("\n")
      |> List.pop_at(-1)

    resp = Enum.map(whole_lines, &{:line, &1})

    {resp, Map.put(state, :remainder, remainder)}
  end

  @spec decode_json_objects(Enumerable.t(Provider.http_chunk_t())) ::
          Enumerable.t(Provider.http_chunk_t() | {:object, binary()})
  def decode_json_objects(stream) do
    stream
    |> transform_to_lines()
    |> Stream.flat_map(fn
      {:line, line} ->
        case Jason.decode(line) do
          {:error, error} ->
            Logger.error(
              "Could not decode JSON - chunk seems to be malformed",
              library: :k8s,
              error: error
            )

            []

          {:ok, object} ->
            [{:object, object}]
        end

      other ->
        [other]
    end)
  end
end
