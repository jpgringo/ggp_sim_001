defmodule GenePrototype0001.Test.Acceptance.Evolution do
  use ExUnit.Case, async: false
  #  import ExUnit.CaptureLog
  #  import ExUnit.CaptureIO
  require DirectDebug

  alias GenePrototype0001.Test.TestSupport
  alias GenePrototype0001.Test.TestingSimulator
  alias GenePrototype0001.Reports.ScenarioRunReportServer

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

  describe "fitness functions" do
    @describetag :evaluation
    @describetag :evolution

    test "check basic fitness function", _state do
      DirectDebug.section("starting 'check agent data'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = ["A", "B", "C", "D"]
      triggering_sensor_event_counts = [2,4,6,8]
      agent_params = Enum.zip([agent_ids, triggering_sensor_event_counts])

      sensor_event_generator = TestSupport.make_sensor_event_generator(run_id,
        agent_params,
        50)

      report = TestSupport.run_scenario_with_report(resource_id, run_id, agent_ids, sensor_event_generator)

      case report do
        r when r.scenario_run_id == run_id -> r
        r -> assert false, "expected report with run_id '#{run_id}'; got #{inspect(r)}"
      end

      DirectDebug.section("report! #{inspect(report)}")

      assert false
    end
  end
end
