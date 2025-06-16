defmodule GenePrototype0001.Test.Acceptance.Reporting do
  use ExUnit.Case, async: false
  #  import ExUnit.CaptureLog
  #  import ExUnit.CaptureIO
  require DirectDebug

  alias GenePrototype0001.Test.TestSupport
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
      DirectDebug.info("starting 'check report creation on scenario termination'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = ["A"]

      # initialize the scenario
      DirectDebug.info("about to start scenario...")
      scenario =  case TestSupport.start_scenario(resource_id, run_id, agent_ids, 1) do
        :error -> nil
        s -> s
      end


      DirectDebug.warning("made it past scenario initialization. scenario: #{inspect(scenario)}")

      %{scenario_name: scenario_resource_id, id: run_id, agents: agents} = case TestSupport.stop_scenario(resource_id, run_id) do
        :error -> assert false, "did not receive scenario termination message"
        result -> DirectDebug.warning("received scenario termination! result: #{inspect(result)}")
          result
      end

      DirectDebug.info("**** scenario_resource_id: #{scenario_resource_id}")

      ScenarioRunReportServer.submit_report(NaiveDateTime.local_now() |> NaiveDateTime.to_iso8601(), scenario_resource_id, run_id, agents)

      case ScenarioRunReportServer.get_report(scenario_resource_id, run_id) do
        report when report.scenario_run_id == run_id -> assert true
        report -> assert false, "expected report with run_id '#{run_id}'; got #{inspect(report)}"
      end
    end
  end

end
