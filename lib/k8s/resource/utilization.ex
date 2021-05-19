defmodule K8s.Resource.Utilization do
  @moduledoc "Deserializers for CPU and Memory values"

  # Symbol -> bytes
  @binary_multipliers %{
    "Ki" => 1024,
    "Mi" => 1_048_576,
    "Gi" => 1_073_741_824,
    "Ti" => 1_099_511_627_776,
    "Pi" => 1_125_899_906_842_624,
    "Ei" => 1_152_921_504_606_846_976
  }

  @decimal_multipliers %{
    "" => 1,
    "k" => 1000,
    "m" => 1_000_000,
    "M" => 1_000_000,
    "G" => 1_000_000_000,
    "T" => 1_000_000_000_000,
    "P" => 1_000_000_000_000_000,
    "E" => 1_000_000_000_000_000_000
  }

  @doc """
  Deserializes CPU quantity

  ## Examples
    Parses whole values
      iex> K8s.Resource.Utilization.cpu("3")
      3

    Parses millicpu values
      iex> K8s.Resource.Utilization.cpu("500m")
      0.5

    Parses decimal values
      iex> K8s.Resource.Utilization.cpu("1.5")
      1.5

  """
  @spec cpu(binary()) :: number
  def cpu(nil), do: 0
  def cpu("-" <> str), do: -1 * deserialize_cpu_quantity(str)
  def cpu("+" <> str), do: deserialize_cpu_quantity(str)
  def cpu(str), do: deserialize_cpu_quantity(str)

  @spec deserialize_cpu_quantity(binary()) :: number
  defp deserialize_cpu_quantity(str) do
    contains_decimal = String.contains?(str, ".")

    {value, maybe_millicpu} =
      case contains_decimal do
        true -> Float.parse(str)
        false -> Integer.parse(str)
      end

    case maybe_millicpu do
      "m" -> value / 1000
      _ -> value
    end
  end

  @doc """
  Deserializes memory quantity

  ## Examples
    Parses whole values
      iex> K8s.Resource.Utilization.memory("1000000")
      1000000

    Parses decimal values
      iex> K8s.Resource.Utilization.memory("10.75")
      10.75

    Parses decimalSI values
      iex> K8s.Resource.Utilization.memory("10M")
      10000000

    Parses binarySI suffixes
      iex> K8s.Resource.Utilization.memory("50Mi")
      52428800

    Returns the numeric value when the suffix is unrecognized
      iex> K8s.Resource.Utilization.memory("50Foo")
      50

  """
  @spec memory(binary()) :: number
  def memory(nil), do: 0
  def memory("-" <> str), do: -1 * deserialize_memory_quantity(str)
  def memory("+" <> str), do: deserialize_memory_quantity(str)
  def memory(str), do: deserialize_memory_quantity(str)

  @spec deserialize_memory_quantity(binary) :: number
  defp deserialize_memory_quantity(str) do
    contains_decimal = String.contains?(str, ".")

    {value, maybe_multiplier} =
      case contains_decimal do
        true -> Float.parse(str)
        false -> Integer.parse(str)
      end

    multiplier = @binary_multipliers[maybe_multiplier] || @decimal_multipliers[maybe_multiplier]

    case multiplier do
      nil ->
        value

      mult ->
        value * mult
    end
  end
end
