defmodule GeneticsEngine.Test.Acceptance.SimulationRuns do

  use ExUnit.Case, async: false
  #  import ExUnit.CaptureLog
  #  import ExUnit.CaptureIO
  require DirectDebug

  alias GeneticsEngine.Test.TestSupport
  alias GeneticsEngine.Test.TestingSimulator
  alias GeneticsEngine.Test.MessageConfirmation

  alias GeneticsEngine.Sim.Scenario
  alias GeneticsEngine.Onta.Ontos

  @moduletag :external

  setup_all do
    opts =  %{
      send_ip: "127.0.0.1",
      # note the send/receive reversal; this is mimicking an external client
      send_port: Application.get_env(:genetics_engine, :receive_port, 7400),
      receive_port: Application.get_env(:genetics_engine, :send_port, 7401)
    }

    :pg.start_link()
    test_sim_pid = start_supervised!({TestingSimulator, opts})

    {:ok, %{test_sim: test_sim_pid}}
  end

  setup do
    :ok
  end

  describe "stop scenarios" do
    @tag :stop_scenarios
    test "explicitly stop scenario" do
      DirectDebug.section("starting 'explicitly stop scenario'...")

      :pg.join(:scenario_events, self())
      :pg.join(:ontos_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = [TestSupport.make_agent_id()]

      DirectDebug.info("agent_ids: #{inspect(agent_ids)}")

      %{pid: scenario_pid} = case TestSupport.start_scenario(resource_id, run_id, agent_ids, 1) do
        :error -> nil
        s -> s
      end

      assert Process.alive?(scenario_pid), "scenario process should be alive"

      # there should be the same number of agents as requests, with the correct ids
      {:ok, onta} = Scenario.get_onta(scenario_pid)
      assert length(onta) == length(agent_ids)

      Enum.each(onta, fn o ->
        %{raw_id: raw_id} = Ontos.get_state(o)
        assert raw_id in agent_ids
      end)

      TestSupport.stop_scenario(resource_id, run_id)

      # scenario should no longer be running
      assert !Process.alive?(scenario_pid), "scenario process should no longer be alive"
      Enum.each(onta, fn o_pid ->
        assert !Process.alive?(o_pid), "onta process should no longer be alive"
      end)
    end
  end

  describe "signalling" do
    @tag :signalling
    test "Ontos signals parent scenario on reaching target" do
      DirectDebug.section("Ontos signals parent scenario on reaching target'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = [TestSupport.make_agent_id(), TestSupport.make_agent_id()]

      DirectDebug.info("agent_ids: #{inspect(agent_ids)}")

      %{pid: scenario_pid} = case TestSupport.start_scenario(resource_id, run_id, agent_ids, 1) do
        :error -> nil
        s -> s
      end

      assert Process.alive?(scenario_pid), "scenario process should be alive"
      {:ok, [first_ontos_pid | _ ]} = Scenario.get_onta(scenario_pid)
      Ontos.test_event(first_ontos_pid, :target_reached, [])

      end

    end
  end
