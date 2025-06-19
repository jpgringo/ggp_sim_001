defmodule GenePrototype0001.Test.Acceptance.Reporting do
  use ExUnit.Case, async: false
  #  import ExUnit.CaptureLog
  #  import ExUnit.CaptureIO
  require DirectDebug

  alias GenePrototype0001.Test.TestSupport
  alias GenePrototype0001.Test.TestingSimulator
  alias GenePrototype0001.Reports.ScenarioRunReportServer

  @moduletag :reporting

  setup_all do
    simulator_opts =  %{
      send_ip: "127.0.0.1",
      # note the send/receive reversal; this is mimicking an external client
      send_port: Application.get_env(:gene_prototype_0001, :receive_port, 7400),
      receive_port: Application.get_env(:gene_prototype_0001, :send_port, 7401)
    }

    test_sim_pid = start_supervised!({TestingSimulator, simulator_opts})

    pg_scope = :reporting_acceptance
    :pg.start_link()
    pg_server = :pg.start_link(pg_scope)
    {:ok, %{test_sim: test_sim_pid, pg_scope: pg_scope, pg_server: pg_server}}
  end

  setup do
    :ok
  end

  describe "report creation and retrieval" do
    @describetag :reporting

    test "check report creation on scenario termination", _state do
      DirectDebug.section("starting 'check report creation on scenario termination'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = ["A"]

      run_scenario_with_report(resource_id, run_id, agent_ids)

      case ScenarioRunReportServer.get_report(resource_id, run_id) do
        report when report.scenario_run_id == run_id -> assert true
        report -> assert false, "expected report with run_id '#{run_id}'; got #{inspect(report)}"
      end
    end
  end

  describe "report contents" do
    @describetag :reporting

    test "check agent data", _state do
      DirectDebug.section("starting 'check agent data'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = ["A", "B", "C", "D"]
      triggering_sensor_event_counts = [2,4,6,8]
      agent_params = Enum.zip([agent_ids, triggering_sensor_event_counts])

      sensor_event_generator = make_sensor_event_generator(run_id,
        agent_params,
        50)

      run_scenario_with_report(resource_id, run_id, agent_ids, sensor_event_generator)

      report = case ScenarioRunReportServer.get_report(resource_id, run_id) do
        report when report.scenario_run_id == run_id -> report
        report -> assert false, "expected report with run_id '#{run_id}'; got #{inspect(report)}"
      end

      DirectDebug.section("report! #{inspect(report)}")

      # confirm the number of agents and the correct ids
      assert length(report.agents) == length(agent_ids)
      assert (Enum.map(report.agents, & &1["id"]) |> Enum.sort) == Enum.sort(agent_ids)

      first_agent = Enum.find(report.agents, & &1["id"] == List.first(agent_ids))

      case Map.get(first_agent, "events") do
        nil -> assert false, "no events found in report agent '#{first_agent["id"]}'"
        events -> case Map.get(events, "actuators", []) do
          [] -> assert false, "no actuator events"
          actuators ->
            expected_actuators =
              Enum.find(agent_params, fn {id, _} -> id == first_agent["id"] end)
                                 |> (fn {_, actuators} -> actuators end).()
            DirectDebug.warning("expected_actuators=#{inspect(expected_actuators)}")
            assert actuators == expected_actuators, "actuators: #{inspect(actuators)}"
        end
      end
    end
  end

  defp run_scenario_with_report(resource_id, run_id, agent_ids, sensor_event_fn \\ nil) do
    # initialize the scenario
    DirectDebug.info("about to start scenario...")
    case TestSupport.start_scenario(resource_id, run_id, agent_ids, 1) do
      :error -> nil
      s -> s
    end

    if is_function(sensor_event_fn) do
      sensor_event_fn.()
    end

    %{scenario_name: scenario_resource_id, id: run_id, agents: agents} = case TestSupport.stop_scenario(resource_id, run_id) do
      :error -> assert false, "did not receive scenario termination message"
      result -> DirectDebug.warning("received scenario termination! result: #{inspect(result)}")
                result
    end
  end

  defp make_sensor_event_generator(run_id, agent_params, period) do
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
