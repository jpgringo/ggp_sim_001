defmodule GenePrototype0001.Test.OntaUnits do
  use ExUnit.Case, async: true
  #  import ExUnit.CaptureLog
  #  import ExUnit.CaptureIO
  require DirectDebug

  @tag :onta
  @tag :unit

  alias GenePrototype0001.Onta.Ontos

#  alias GenePrototype0001.Test.TestSupport

  describe "data preprocessing" do
    @describetag :unit

    test "preprocess single data event", _state do
      processed_set = Ontos.preprocess_data_batch([
        [0, [0, 0, 0]]
      ])
      DirectDebug.info("processed_set: #{inspect(processed_set)}")
      expected_set = [[0, [0.0, 0.0, 0.0]]]
      assert processed_set == expected_set
    end

    test "preprocess multiple events for one sensor", _state do
      processed_set = Ontos.preprocess_data_batch([
        [0, [0, 0, 0]],
        [0, [0, 1, 2]],
        [0, [0, 2, 4]],
        [0, [0, 3, 6]],
        [0, [0, 4, 8]],
      ])
      DirectDebug.info("processed_set: #{inspect(processed_set)}")
      expected_set = [[0, [0.0, 2.0, 4.0]]]
      assert processed_set == expected_set
    end
  end
end
