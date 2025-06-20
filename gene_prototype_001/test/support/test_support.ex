defmodule GenePrototype0001.Test.TestSupport do
  @moduledoc false

  use ExUnit.Case

  alias GenePrototype0001.Test.MessageConfirmation
  alias GenePrototype0001.Sim.ScenarioSupervisor
  alias GenePrototype0001.Reports.ScenarioRunReportServer
  alias GenePrototype0001.Test.TestingSimulator

  @alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def make_resource_id() do
    Nanoid.generate(8, @alphabet)
  end

  def make_run_id() do
    Nanoid.generate(8, @alphabet)
  end

  def create_and_validate_scenario(scenario_resource_id \\nil, run_id \\nil, port \\ 7400) do
    scenario_resource_id = case scenario_resource_id do
      nil -> Nanoid.generate(8, ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
      _ -> scenario_resource_id
    end

    run_id = case run_id do
      nil ->
        Nanoid.generate(12)
      _ -> run_id
    end

    %{ip: ip, port: port, payload: payload} = make_scenario_params(scenario_resource_id, run_id, port)

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

def make_scenario_params(scenario_resource_id, run_id, port \\ 7400) do
  {:ok, ip} = :inet.parse_address(~c"127.0.0.1")
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

  def start_scenario(resource_id, run_id, agent_ids, actuators) do
    DirectDebug.info("starting scenario #{resource_id}_#{run_id}...")

    agents = Enum.map(agent_ids, & %{id: &1, actuators: actuators})

    DirectDebug.extra("agents: #{inspect(agents)}")
    # first, tell the sim to start the scenario
    TestingSimulator.initiate_scenario_run(%{resource_id: resource_id,
      run_id: run_id,
      agents: agents
    })

    case Process.whereis(:pg) do
      nil -> MessageConfirmation.wait_for_confirmation(fn msg ->
                               case msg do
                                 {:scenario_inited, run_id, pid} -> DirectDebug.info("scenario '#{run_id} inited at #{inspect(pid)}")
                                 msg ->
                                   DirectDebug.info("Blackbox received unknown confirmation message: #{inspect(msg)}")
                                   assert false
                                   {:noreply, :ok}
                               end
      end, "scenario not created")
      _ ->
        DirectDebug.section("WAITING for confirmation via :pg...")
        MessageConfirmation.wait_for_confirmation(fn msg ->
            case msg do
              {:scenario_inited, scenario_details} -> DirectDebug.info("TestSupport.start_scenario - scenario: #{inspect(scenario_details)}")
                {:ok, scenario_details}
              msg -> DirectDebug.warning("TestSupport.start_scenario - got msg: #{inspect(msg)}")
                     :error
            end
          end, "start scenario confirmation not received", 2000)
    end
  end

  def stop_scenario(resource_id, run_id) do
    DirectDebug.info("stopping scenario #{resource_id}_#{run_id}...")

    TestingSimulator.stop_scenario_run(resource_id, run_id)

    if Process.whereis(:pg) != nil do
      DirectDebug.warning("will WAIT for scenario termination...")
      MessageConfirmation.wait_for_confirmation(fn msg ->
                               case msg do
                                 {:scenario_terminated, scenario_details} ->
                                   DirectDebug.info("TestSupport.stop_scenario - scenario: #{inspect(scenario_details)}")
                                   {:ok, scenario_details}
                                 msg -> DirectDebug.warning("TestSupport.stop_scenario - got msg: #{inspect(msg)}")
                                        :error
                               end
      end)
    end

      # "{\"jsonrpc\":\"2.0\",\"method\":\"scenario_stopped\",\"params\":{\"id\":\"B9SRXNCR\",\"scenario\":\"map_0001.json\"}}"}
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

# ============ DEVELOPED DURING REPORTING =========================#

  def run_scenario_with_report(resource_id, run_id, agent_ids, sensor_event_fn \\ nil) do
    # initialize the scenario
    DirectDebug.info("about to start scenario...")
    case start_scenario(resource_id, run_id, agent_ids, 1) do
      :error -> nil
      s -> s
    end

    if is_function(sensor_event_fn) do
      sensor_event_fn.()
    end

    %{scenario_name: scenario_resource_id, id: run_id, agents: agents} = case stop_scenario(resource_id, run_id) do
      :error -> assert false, "did not receive scenario termination message"
      result -> DirectDebug.warning("received scenario termination! result: #{inspect(result)}")
                result
    end

    case ScenarioRunReportServer.get_report(resource_id, run_id) do
      report when report.scenario_run_id == run_id -> report
      report -> nil
    end


  end

  def make_sensor_event_generator(run_id, agent_params, period) do
    DirectDebug.extra("make_sensor_event_generator - agent params: #{inspect(agent_params)}")
    fn () ->
      # some Elixir-style fake anonymous recursion here
      send_event = fn
        _f, [] -> :ok
        f, params -> index = :rand.uniform(length(params)) - 1
                     {agent_id, remaining} = Enum.at(params, index)
                     DirectDebug.warning("would generate event for agent #{agent_id} (#{remaining} remaining)")
                     TestingSimulator.send_sensor_data_batch(run_id, [{agent_id, [0, [0, 0, 0]]}])
                     Process.sleep(period)
                     cond do
                       remaining > 1 ->
                         f.(f, List.update_at(params, index, fn {_k, v} -> {agent_id, remaining - 1} end))
                       remaining == 1 ->
                         f.(f, List.delete_at(params, index))
                     end
      end

      send_event.(send_event, agent_params) # ... by passing the function to itself as an argument
    end
  end

end
