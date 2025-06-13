defmodule GenePrototype0001.Test.TestSupport do
  @moduledoc false

  use ExUnit.Case

  alias GenePrototype0001.Sim.ScenarioSupervisor

  def create_and_validate_scenario(scenario_resource_id \\nil, run_id \\nil) do
    scenario_resource_id = case scenario_resource_id do
      nil -> Nanoid.generate(8, ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
      _ -> scenario_resource_id
    end

    run_id = case run_id do
      nil ->
        Nanoid.generate(12)
      _ -> run_id
    end

    %{ip: ip, port: port, payload: payload} = make_scenario_params(scenario_resource_id, run_id)

    send(:SimUdpConnector, {:udp, nil, ip, port, payload, [self()]})

    scenario_timeout = 3000
    receive do
      # The message will really be this `{:scenario_inited, _scenario_name, _pid} -> :ok`, but really any message at all is fine
      _ -> :ok
    after
      scenario_timeout ->
        :timeout
        assert false, "scenario not created within #{scenario_timeout}ms"
    end

    scenario_pid = case check_for_scenario(scenario_resource_id, run_id) do
      {:ok, pid} ->
        assert true
        pid
      {:error, reason} -> assert false, "scenario not created: #{inspect(reason)}"
    end

    %{scenario_resource_id: scenario_resource_id, run_id: run_id, ip: ip, port: port, pid: scenario_pid}
end

def make_scenario_params(scenario_resource_id, run_id) do
  {:ok, ip} = :inet.parse_address(~c"127.0.0.1")
  port = 7400
  {:ok, agent_params} = make_agent_params(3,1,true)
  payload =
    ~s"""
      {
        "jsonrpc":"2.0",
        "method":"scenario_started",
        "params":{
          "scenario":"#{scenario_resource_id}",
          "unique_id":"#{run_id}",
           "agents":#{agent_params}
         }
      }
      """
  %{ip: ip, port: port, payload: payload}
end

def check_for_scenario(resource_id, run_id, should_exist? \\true) do
  case ScenarioSupervisor.has_scenario?(resource_id, run_id) do
    {:ok, pid} when should_exist? ->
      IO.puts("exists, all good")
      {:ok, pid}
    {:ok, _} ->
      IO.puts("exists, but shouldn't")
      {:error, :scenario_exists_but_shouldnt}
    {:error, reason} when should_exist? ->
      IO.puts("doesn't exist, but should")
      {:error, reason}
    {:error, reason} ->
      IO.puts("doesn't exist, all good")
      {:error, reason}
  end
end



def make_agent_params(agent_count, actuator_count, as_json? \\ false) do
  #  %{"agents" => [%{"actuators" => 1, "id" => "48184165825"}, %{"actuators" => 1, "id" => "48284829114"}], "scenario" => "map_0000.json", "unique_id" => "VDSCDZM0"}
  agent_params = Enum.map(1..agent_count, fn _ -> %{"id" => Nanoid.generate(15), "actuators" => actuator_count} end)
  if as_json? do
    Jason.encode(agent_params)
  else
    agent_params
  end
end

end
