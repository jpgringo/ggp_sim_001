defmodule GeneticsEngine.Reports.ScenarioRunReportServerTest do
  use ExUnit.Case, async: true

  alias GeneticsEngine.Reports.ScenarioRunReportServer

  @tag :reports

  setup do
    # Clear any existing reports
    ScenarioRunReportServer.clear_reports()
    :ok
  end

  test "submits and retrieves reports" do
    # Create a sample report
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    scenario_resource_id = "resource_123"
    scenario_run_id = "run_456"
    agents = [
      %{
        id: "agent_1",
        actuator_commands: 10,
        numina: ["GeneticsEngine.Numina.BasicMotionNumen"]
      },
      %{
        id: "agent_2",
        actuator_commands: 5,
        numina: ["GeneticsEngine.Numina.BasicMotionNumen"]
      }
    ]

    # Submit the report
    :ok = ScenarioRunReportServer.submit_report(timestamp, scenario_resource_id, scenario_run_id, agents)

    # Retrieve all reports
    reports = ScenarioRunReportServer.get_reports()

    # Verify the report was stored correctly
    assert length(reports) == 1
    report = hd(reports)
    assert report.timestamp == timestamp
    assert report.scenario_resource_id == scenario_resource_id
    assert report.scenario_run_id == scenario_run_id
    assert length(report.agents) == 2

    # Verify the first agent
    agent1 = Enum.find(report.agents, fn a -> a.id == "agent_1" end)
    assert agent1.actuator_commands == 10
    assert agent1.numina == ["GeneticsEngine.Numina.BasicMotionNumen"]

    # Verify the second agent
    agent2 = Enum.find(report.agents, fn a -> a.id == "agent_2" end)
    assert agent2.actuator_commands == 5
    assert agent2.numina == ["GeneticsEngine.Numina.BasicMotionNumen"]
  end

  test "clears reports" do
    # Submit a report
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    ScenarioRunReportServer.submit_report(timestamp, "resource_123", "run_456", [])

    # Verify the report was stored
    reports = ScenarioRunReportServer.get_reports()
    assert length(reports) == 1

    # Clear the reports
    :ok = ScenarioRunReportServer.clear_reports()

    # Verify the reports were cleared
    reports = ScenarioRunReportServer.get_reports()
    assert reports == []
  end

  test "stores multiple reports" do
    # Submit multiple reports
    timestamp1 = DateTime.utc_now() |> DateTime.to_iso8601()
    timestamp2 = DateTime.utc_now() |> DateTime.add(1) |> DateTime.to_iso8601()

    ScenarioRunReportServer.submit_report(timestamp1, "resource_1", "run_1", [])
    ScenarioRunReportServer.submit_report(timestamp2, "resource_2", "run_2", [])

    # Retrieve all reports
    reports = ScenarioRunReportServer.get_reports()

    # Verify both reports were stored
    assert length(reports) == 2

    # Reports are stored in reverse order (newest first)
    assert hd(reports).scenario_run_id == "run_2"
    assert List.last(reports).scenario_run_id == "run_1"
  end
end
