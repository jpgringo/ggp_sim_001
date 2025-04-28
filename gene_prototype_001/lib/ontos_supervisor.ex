defmodule GenePrototype0001.OntosSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    Logger.info("Starting Ontos supervisor...")
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Initializing Ontos supervisor...")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_ontos(agent_id, params \\ %{}) do
    available_actuators = Map.get(params, "actuators", 0)
    numina = Map.get(params, "numina", [GenePrototype0001.Numina.BasicMotionNumen])
    spec = {GenePrototype0001.Ontos, {agent_id, [available_actuators: available_actuators, numina: numina]}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_ontos(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
