defmodule GenePrototype0001.Bandit.LiveIntegrationTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import ExUnit.CaptureIO

  @moduletag :integration

  alias GenePrototype0001.Sim.ScenarioSupervisor

  setup_all do
    port = 4003
    capture_io(fn ->
      capture_log(fn ->
          start_supervised!({Bandit, plug: GenePrototype0001.Bandit.Router, scheme: :http, port: port})
      end)
    end)
    {:ok, base_url: "http://localhost:#{port}"}
  end

  setup do
    :ok
  end

  describe "object instantiation without external interface" do
    test "Create a new scenario internally", _state do
      scenario_resource_id = "quux"
      run_id = Nanoid.generate(12)
      check_for_scenario(scenario_resource_id, run_id, false)
      agent_count = 3
      opts = %{
        "scenario" => scenario_resource_id,
        "unique_id" => run_id,
        "agents" =>  make_agent_params(agent_count, 1)
      }
      instantiate_scenario(opts)
      {:ok, scenario_pid} = check_for_scenario(scenario_resource_id, run_id)
      {:ok, onta} = check_for_onta(scenario_pid, agent_count)
      check_all_onta_for_numina(onta)
      {:ok}
    end
  end

  describe "object instantiation WITH external interface" do
    test "receive scenario_started via UDP" do
      {:ok, ip} = :inet.parse_address(~c"127.0.0.1")
      scenario_name = "fnord"
      scenario_id = Nanoid.generate(12)
      IO.puts("will generate agent params")
      {:ok, agent_params} = make_agent_params(3,1,true)
      IO.puts("agent_params: #{inspect(agent_params)}")
      send(:SimUdpConnector, {:udp, nil, ip, 7400,
        ~s"""
        {
          "jsonrpc":"2.0",
          "method":"scenario_started",
          "params":{
            "scenario":"#{scenario_name}",
            "unique_id":"#{scenario_id}",
            "agents":#{agent_params}
          }
        }
        """,
        [self()]
      })

      scenario_timeout = 3000
      receive do
        # The message will really be this `{:scenario_inited, _scenario_name, _pid} -> :ok`, but really any message at all is fine
        _ -> :ok
      after
        scenario_timeout ->
          :timeout
          assert false, "scenario not created within #{scenario_timeout}ms"
      end

      case check_for_scenario(scenario_name, scenario_id) do
        {:ok, _pid} -> assert true
        {:error, reason} -> assert false, "scenario not created: #{inspect(reason)}"
      end
    end
  end

  # ============================  SUPPORTING FUNCTIONS ============================ #

  def wait_until(fun, timeout \\ 500, interval \\ 10) do
    start = System.monotonic_time(:millisecond)
    do_wait_until(fun, start, timeout, interval)
  end

  defp do_wait_until(fun, start, timeout, interval) do
    now = System.monotonic_time(:millisecond)
    if now - start > timeout do
      raise "Condition not met within #{timeout}ms"
    end

    IO.puts("Checking condition...")
    case fun.() do
      true ->
        IO.puts("Condition met!")
        true
      false ->
        IO.puts("Condition not met, sleeping #{interval}ms")
        Process.sleep(interval)
        do_wait_until(fun, start, timeout, interval)
    end
  end

  defp make_agent_params(agent_count, actuator_count, as_json? \\ false) do
    #  %{"agents" => [%{"actuators" => 1, "id" => "48184165825"}, %{"actuators" => 1, "id" => "48284829114"}], "scenario" => "map_0000.json", "unique_id" => "VDSCDZM0"}
    agent_params = Enum.map(1..agent_count, fn _ -> %{"id" => Nanoid.generate(15), "actuators" => actuator_count} end)
    if as_json? do
        Jason.encode(agent_params)
    else
        agent_params
    end

  end

  defp check_for_scenario(resource_id, run_id, should_exist? \\true) do
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

  defp instantiate_scenario(opts) do
    case ScenarioSupervisor.start_scenario(opts) do
      {:ok, pid} ->
        assert true
        {:ok, %{scenario_pid: pid}}
      {:error, _} -> assert false
    end
  end

  defp check_for_onta(scenario, expected_onta) do
    {:ok, onta} = GenServer.call(scenario, :get_onta)
    assert length(onta) == expected_onta
    {:ok, onta}
  end

  defp check_all_onta_for_numina(onta_pids, min_numina \\ 1) do
    Enum.map(onta_pids, fn ontos_pid ->
      IO.puts("will check Ontos at #{inspect(ontos_pid)}")
      check_for_numina(ontos_pid, min_numina)
    end)
  end

  defp check_for_numina(ontos_pid, min_numina \\ 1) do
    case GenServer.call(ontos_pid, :get_numina) do
      {:ok, numina_pids} when length(numina_pids) >= min_numina -> assert true
      {:ok, numina_pids} ->
        %{agent_id: agent_id} = GenServer.call(ontos_pid, :get_state)
        assert false, "#{inspect(agent_id)} expected >= #{min_numina} numina; got #{length(numina_pids)}"
    end
  end

end
