defmodule GenePrototype0001.Sim.ScenarioSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    Logger.info("Starting Scenario supervisor...")
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Initializing Scenario supervisor...")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_scenario(scenario_name, params \\ %{}) do
    spec = {GenePrototype0001.Sim.Scenario, {scenario_name, []}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
#
#  def terminate_ontos(pid) when is_pid(pid) do
#    DynamicSupervisor.terminate_child(__MODULE__, pid)
#  end
end
