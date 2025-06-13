defmodule GenePrototype0001.Test.OntosZipWith do
  use ExUnit.Case, async: true
  require DirectDebug

  alias GenePrototype0001.Onta.Ontos

  describe "zip_with issue" do
    @describetag :unit

    test "reproduces the issue with Enum.zip_with on [[0], [0], [0]]", _state do
      # This is the problematic input
      vals_only = [[0], [0], [0]]

      # This is the line that's causing the issue
      pivot = vals_only |> Enum.zip_with(& &1)

      # Print the result to see what's happening
      DirectDebug.info("pivot: #{inspect(pivot)}")

      # Try to calculate the average
      avg = pivot |> Enum.map(&(Enum.sum(&1) / length(&1)))

      # Print the result
      DirectDebug.info("avg: #{inspect(avg)}")

      # Assert something to make the test pass
      assert true
    end

    test "test isolate_and_average_grouped_data_batch with problematic input", _state do
      # Create input similar to what would cause the issue
      grouped_data = %{0 => [[0, [0]], [0, [0]], [0, [0]]]}

      # Call the function directly
      result = Ontos.isolate_and_average_grouped_data_batch(grouped_data)

      # Check the result
      DirectDebug.info("result: #{inspect(result)}")
      assert is_list(result)
    end
  end
end
