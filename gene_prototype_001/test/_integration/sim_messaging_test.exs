defmodule GenePrototype0001.Test.SimMessaging do
  use ExUnit.Case, async: false
#  import ExUnit.CaptureLog
#  import ExUnit.CaptureIO

  alias GenePrototype0001.Test.TestSupport
#  alias GenePrototype0001.Sim.ScenarioSupervisor

  @moduletag :integration


  describe "incoming sensor data batches" do
    test "receive single sensor data batch", _state do
      %{scenario_resource_id: scenario_resource_id, run_id: run_id, ip: ip, port: port, pid: scenario_pid} = TestSupport.create_and_validate_scenario()
      IO.puts(">>>>>>>>>> scenario created: #{inspect(scenario_resource_id)}/#{inspect(run_id)}/#{inspect(scenario_pid)}")

      {:ok, onta} = GenServer.call(scenario_pid, :get_onta)
      agent_ids = Enum.map(onta, fn o ->
        GenServer.call(o, :get_state).raw_id
      end)
      IO.puts("> > > > >  onta: #{inspect(onta)} -> #{inspect(agent_ids)}")

      sensor_data_batch = make_sensor_data_batch(run_id, agent_ids, 7)
      {:ok, batch_json} = Jason.encode(sensor_data_batch)
      IO.puts("sensor_data_batch: #{inspect(sensor_data_batch)}")

      payload = ~s"""
{
  "jsonrpc":"2.0",
  "method":"batch",
  "params":{
    "sensor_data": #{batch_json}
  }
}
"""
      send(:SimUdpConnector, {:udp, nil, ip, port, payload})
    end
  end

  defp make_sensor_data_batch(run_id, agent_ids, reading_count) do
    Enum.map(0..(reading_count - 1), fn i ->
      idx = rem(i, length(agent_ids))
      agent_id = Enum.at(agent_ids, idx)
      %{
        agent: agent_id,
        data: [0,[0.0,0.0]],
        scenario: run_id
      }
    end)
  end
end
