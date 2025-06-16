defmodule GenePrototype0001.Test.TestSupport do
  @moduledoc false

  use ExUnit.Case

  alias GenePrototype0001.Sim.ScenarioSupervisor

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

  @doc """
    waits for receipt of messages during the period defined by timeout and evaluates each received
    message using evaluation_func; evaluation_func must return either{:ok, parsed_or_raw_message},
  or `{:error, reason}` from every execution path
"""
  def wait_for_confirmation(evaluation_func, failure_msg \\ "confirmation not received", timeout \\ 3000) do
    start_time = System.monotonic_time(:millisecond)
    do_wait_for_confirmation(evaluation_func, failure_msg, timeout, start_time)
  end

  defp do_wait_for_confirmation(evaluation_func, failure_msg, timeout, start_time) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - start_time
    remaining = timeout - elapsed
    DirectDebug.warning("waiting for confirmation - rem=#{remaining}")

    if remaining <= 0 do
      assert false, "#{failure_msg} within #{timeout}ms"
    else
      receive do
        msg ->
          case evaluation_func.(msg) do
            {:ok, result} -> result
            _ -> do_wait_for_confirmation(evaluation_func, failure_msg, timeout, start_time)
          end
      after
        remaining ->
          assert false, "#{failure_msg} within #{timeout}ms"
      end
    end
  end

  def start_scenario(resource_id, run_id, agent_ids, actuators) do
    DirectDebug.info("starting scenario #{resource_id}_#{run_id}...")
    encoded_pid = self() |> :erlang.term_to_binary() |> Base.encode64()

    agents = Enum.map(agent_ids, & %{id: &1, actuators: actuators})

    DirectDebug.extra("agents: #{inspect(agents)}")
    # first, tell the sim to start the scenario
    GenServer.call(:TestingSimulator,
      {:initiate_scenario_run,
        %{resource_id: resource_id,
          run_id: run_id,
          agents: agents,
          subscribers: [encoded_pid]
        }})

    case Process.whereis(:pg) do
      nil -> wait_for_confirmation(fn msg ->
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
        wait_for_confirmation(fn msg ->
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

    encoded_pid = self() |> :erlang.term_to_binary() |> Base.encode64()

    GenServer.call(:TestingSimulator,
      {:stop_scenario_run,
        %{resource_id: resource_id,
          run_id: run_id,
          subscribers: [encoded_pid]
        }})

    if Process.whereis(:pg) != nil do
      DirectDebug.warning("will WAIT for scenario termination...")
      wait_for_confirmation(fn msg ->
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

end
