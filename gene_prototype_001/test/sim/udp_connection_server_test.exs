defmodule GenePrototype0001.Sim.UdpConnectionServerTest do
  use ExUnit.Case

  # This test can be run from IEx using:
  # GenePrototype0001.Sim.UdpConnectionServerTest.test_batch_call_has_agent()
  def test_batch_call_has_agent do
    json = ~s({"method": "batch", "params": [{ "agent": 39862666680, "data": [0, [59.8959579467773, -80.0779342651367]] }, { "agent": 39963329981, "data": [0, [0.0, 0.0]] }, { "agent": 39862666680, "data": [0, [-88.4336929321289, -46.6849136352539]] }, { "agent": 39862666680, "data": [0, [-88.4336929321289, -46.6849136352539]] }, { "agent": 39963329981, "data": [0, [0.0, 0.0]] }, { "agent": 40063993282, "data": [0, [-27.5572185516357, 96.128044128418]] }]})
    {:ok, decoded} = Jason.decode(json)
    IO.inspect(decoded)
    # %{"method" => method, "params" => params} = decoded

    # assert params["agent"] != nil, "Expected params to have a non-null agent field"
    :ok
  end
end
