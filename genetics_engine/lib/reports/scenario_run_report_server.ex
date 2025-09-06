defmodule GeneticsEngine.Reports.ScenarioRunReportServer do
  @moduledoc """
  GenServer that accepts and stores scenario run reports.

  In normal operation, reports are persisted to a JSON file.
  During testing, reports are stored in-memory for later retrieval.
  """

  use GenServer
  require Logger
  require DirectDebug

  @server_name :ScenarioRunReportServer

  # Client API

  @doc """
  Starts the ScenarioRunReportServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @server_name)
  end

  @doc """
  Submits a scenario run report.

  ## Parameters

  - `timestamp`: The timestamp of the report
  - `scenario_resource_id`: The ID of the scenario resource
  - `scenario_run_id`: The ID of the scenario run
  - `agents`: A list of agents/Onta, each containing:
    - `id`: The ID of the agent/Onta
    - `actuator_commands`: The number of actuator commands issued
    - `numina`: A list of Numina associated with the agent/Onta
  """
  def submit_report(timestamp, scenario_resource_id, scenario_run_id, agents) do
    GenServer.call(@server_name, {:submit_report, timestamp, scenario_resource_id, scenario_run_id, agents})
  end

  @doc """
  Retrieves all stored reports.
  """
  def get_reports do
    GenServer.call(@server_name, :get_reports)
  end

  @doc """
  Retrieves stored report that matches scenario resource id and run id.
  """
  def get_report(scenario_resource_id, run_id) do
    GenServer.call(@server_name, {:get_report, scenario_resource_id, run_id})
  end

  @doc """
  Clears all stored reports.
  Only useful during testing.
  """
  def clear_reports do
    GenServer.call(@server_name, :clear_reports)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    DirectDebug.info("Starting ScenarioRunReportServer")

    # Create the reports directory if it doesn't exist (only in non-test environment)
    unless Mix.env() == :test do
      File.mkdir_p!(reports_dir())
    end

    {:ok, %{reports: []}}
  end

  @impl true
  def handle_call({:submit_report, timestamp, scenario_resource_id, scenario_run_id, agents}, _from, state) do
    report = %{
      timestamp: timestamp,
      scenario_resource_id: scenario_resource_id,
      scenario_run_id: scenario_run_id,
      agents: agents
    }

    DirectDebug.info("Received scenario run report: #{inspect(report)}")

    # Store the report
    new_state = if Mix.env() == :test do
      # In test environment, store in memory
      %{state | reports: [report | state.reports]}
    else
      # In non-test environment, persist to file
      persist_report(report)
      state
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_reports, _from, state) do
    {:reply, state.reports, state}
  end

  @impl true
  def handle_call({:get_report, scenario_resource_id, run_id}, _from, state) do
    report = Enum.filter(state.reports, & &1.scenario_resource_id == scenario_resource_id && &1.scenario_run_id == run_id)
    |> (fn matches -> case matches do
        matches when matches != [] -> [r | _] = matches
          r
        _ -> nil
                       end
        end).()
    {:reply, report, state}
  end

  @impl true
  def handle_call(:clear_reports, _from, _state) do
    {:reply, :ok, %{reports: []}}
  end

  # Private functions

  defp persist_report(report) do
    # Generate a unique filename based on timestamp and run ID
    filename = "#{report.timestamp}_#{report.scenario_run_id}.json"
    path = Path.join(reports_dir(), filename)

    # Convert the report to JSON and write to file
    case Jason.encode(report, pretty: true) do
      {:ok, json} ->
        case File.write(path, json) do
          :ok ->
            DirectDebug.info("Scenario run report persisted to #{path}")
            :ok
          {:error, reason} ->
            DirectDebug.error("Failed to write scenario run report to #{path}: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        DirectDebug.error("Failed to encode scenario run report to JSON: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp reports_dir do
    Path.join(Application.app_dir(:genetics_engine), "priv/reports")
  end
end
