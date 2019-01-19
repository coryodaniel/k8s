defmodule Mix.K8s do
  @moduledoc """
  Mix task helpers
  """

  @doc "Parse CLI input"
  def parse_args(args, defaults, cli_opts \\ []) do
    {opts, parsed, invalid} = OptionParser.parse(args, cli_opts)
    merged_opts = Keyword.merge(defaults, opts)

    {merged_opts, parsed, invalid}
  end

  @doc "Creates a file, optionally rendering to STDOUT"
  def create_file(source, "-"), do: IO.puts(source)

  def create_file(source, target) do
    Mix.Generator.create_file(target, source)
  end
end
