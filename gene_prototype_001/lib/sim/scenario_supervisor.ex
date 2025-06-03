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

  def start_scenario(%{"scenario" => scenario_name, "unique_id" => unique_id, "agents" => agents}) do
    Logger.debug("SIM SUPERVISOR: starting scenario '#{scenario_name}' with unique_id '#{unique_id}' and agents #{inspect(agents)}")

    # Create child spec with proper arguments
    spec = %{
      id: GenePrototype0001.Sim.Scenario,
      start: {GenePrototype0001.Sim.Scenario, :start_link, [scenario_name, unique_id, agents]},
      restart: :permanent,
      shutdown: 300
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        Logger.info("Started scenario '#{scenario_name}' with PID #{inspect(pid)}")
        {:ok, pid}
      {:error, reason} = error ->
        Logger.error("Failed to start scenario '#{scenario_name}': #{inspect(reason)}")
        error
    end
  end

  def start_scenario(scenario_name, params \\ %{}) do
    Logger.debug("SIM SUPERVISOR: starting scenario '#{scenario_name}' with params #{inspect(params)}")

    # Create child spec with proper arguments
    spec = %{
      id: GenePrototype0001.Sim.Scenario,
      start: {GenePrototype0001.Sim.Scenario, :start_link, [{scenario_name, params}]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        Logger.info("Started scenario '#{scenario_name}' with PID #{inspect(pid)}")
        {:ok, pid}
      {:error, reason} = error ->
        Logger.error("Failed to start scenario '#{scenario_name}': #{inspect(reason)}")
        error
    end
  end

  def stop_scenario(scenario_id) do
    Logger.debug("ScenarioSupervisor will attempt to stop scenario with id '#{inspect(scenario_id)}'")
    case Registry.lookup(GenePrototype0001.Sim.ScenarioRegistry, scenario_id) do
      [{pid, _}] ->
        Logger.debug("found scenario with pid '#{inspect(pid)}'... will terminate")
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] ->
        Logger.error("COULD NOT FIND SCENARIO WITH id '#{inspect(scenario_id)}'")
        {:error, :not_found}
    end
  end

  def stop_all() do
    Enum.each(DynamicSupervisor.which_children(__MODULE__), fn {_, child_pid, _, _} ->
                                                              DynamicSupervisor.terminate_child(__MODULE__, child_pid)
                                                            end )
  end
end
