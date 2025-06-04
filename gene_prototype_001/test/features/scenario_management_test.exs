defmodule GenePrototype0001.Features.ScenarioManagementTest do
  use Cabbage.Feature, async: false, file: "scenario_management.feature"
  @tag bdd: true

  alias GenePrototype0001.Sim.ScenarioSupervisor

  setup_all do
    port = 4003
    start_supervised!({Bandit, plug: GenePrototype0001.Bandit.Router, scheme: :http, port: port})
    {:ok, base_url: "http://localhost:#{port}"}
  end

  setup do
    :ok
  end

  # All `defgiven/4`, `defwhen/4` and `defthen/4` takes a regex, matched data, state and lastly a block
  defgiven ~r/^The HTTP service is available$/, _, state do
    # `{:ok, state}` gets returned from each callback which updates the state or
    # leaves the state unchanged when something else is returned
#    {:ok, %{machine: Machine.put_coffee(Machine.new, number)}}
    {:ok, %{}}
  end

  defgiven ~r/^No scenario with the resource id (?<resource_id>(nil|\"[^\"]+\")) and run id "(?<run_id>[^"]+)" exists$/, %{resource_id: resource_id, run_id: run_id}, state do
    quoted? = String.starts_with?(resource_id, "\"") and String.ends_with?(resource_id, "\"")
    resource_id = case resource_id do
      "nil" -> "unknown"
      s when quoted? ->
        <<_, rest::binary>> = s
        String.slice(rest, 0..-2)
      _ -> raise "invalid resource id #{resource_id}"
    end
    scenario_exists = case ScenarioSupervisor.has_scenario?(resource_id, run_id) do
      {:ok, _} -> true
      _ -> false
    end
    assert scenario_exists == false
    {:ok, Map.merge(state, %{resource_id: resource_id, run_id: run_id})}
  end


  defthen ~r/^Server status should be (?<server_status>true|false)$/, %{server_status: server_status}, %{base_url: url} = state do
    server_status = string_to_boolean(server_status)
    {:ok, resp} = Req.get(url <> "/api/status")
    assert resp.body["server"] == server_status
  end

  defwhen ~r/^I pass those scenario variables$/, _vars, state do
    IO.puts("STATE PASS-THROUGH: #{inspect (state)}")
    assert true
  end

  defwhen ~r/^I specify (?<agents>\d+) agents with (?<sensors>\d+) sensors and (?<actuators>\d+) actuators each$/, %{agents: agents, sensors: sensors, actuators: actuators}, state do
    {sensor_count, _} = Integer.parse(sensors)
    {agent_count, _} = Integer.parse(agents)
    assert agent_count + 0> 1
    assert sensor_count + 0  > 1 # not sure why the +0 is necessary, but it seems to be...
    assert actuators > 0
    opts = %{
      "scenario" => state.resource_id,
      "unique_id" => state.run_id,
      "agents" =>  make_agent_params(agent_count, actuators)
    }
    case ScenarioSupervisor.start_scenario(opts) do
      {:ok, pid} ->
        assert true
        {:ok, Map.merge(state, %{scenario_pid: pid})}
      {:error, _} -> assert false
    end
  end

  defthen ~r/^The scenario should be created$/, _vars, state do
    IO.puts("Scenario created? #{inspect(state)}")
    resp = GenServer.call(state.scenario_pid, :get_name)
    IO.puts(":get_name resp: #{inspect(resp)}")
    scenario_exists = case ScenarioSupervisor.has_scenario?(state.resource_id, state.run_id) do
      {:ok, pid} ->
      IO.puts("scenario exists: #{inspect(pid)}")
        true
      _ -> false
    end
    assert scenario_exists == true
    assert true
  end


  # =========================== HELPER FUNCTIONS =========================== #

  defp make_agent_params(agent_count, actuator_count) do
    #  %{"agents" => [%{"actuators" => 1, "id" => "48184165825"}, %{"actuators" => 1, "id" => "48284829114"}], "scenario" => "map_0000.json", "unique_id" => "VDSCDZM0"}
    Enum.map(1..agent_count, fn _ -> %{"id" => Nanoid.generate(15), "actuators" => actuator_count} end)
  end

  def string_to_boolean(str) do
    case str do
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end
end

