defmodule GeneticsEngine.Sim.ScenarioSupervisor do
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

  def has_scenario?(_resource_id, run_id) do
    case Registry.lookup(GeneticsEngine.Sim.ScenarioRegistry, "#{run_id}") do
      [{pid, _}] ->
        {:ok, pid}
      [] ->
        {:error, :not_found}
    end

  end

  def start_scenario(%{"scenario" => scenario_name, "unique_id" => unique_id, "agents" => agents}) do
    DirectDebug.info("SIM SUPERVISOR: starting scenario '#{scenario_name}' with unique_id '#{unique_id}' and agents #{inspect(agents)}", true)

    # Create child spec with proper arguments
    spec = {GeneticsEngine.Sim.Scenario, {scenario_name, unique_id, agents}}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        :logger.info("#{__MODULE__} - Started scenario '#{scenario_name}' with PID #{inspect(pid)}")
        case Process.whereis(:pg) do
          nil -> :ok
          _ ->
            DirectDebug.warning("ScenarioSupervisor - will notify members: #{inspect(:pg.get_members(:scenario_events))}")
            Enum.each(:pg.get_members(:scenario_events), & send(&1, {:scenario_inited, %{resource_id: scenario_name, run_id: unique_id, pid: pid}}))
        end
        {:ok, pid}
      {:error, reason} = error ->
        Logger.error("Failed to start scenario '#{scenario_name}': #{inspect(reason)}")
        error
    end
  end

   def stop_scenario(scenario_id) do
    DirectDebug.info("ScenarioSupervisor will attempt to stop scenario with id '#{inspect(scenario_id)}'")
    case Registry.lookup(GeneticsEngine.Sim.ScenarioRegistry, scenario_id) do
      [{pid, _}] ->
#        Logger.debug("found scenario with pid '#{inspect(pid)}'... will terminate")
#        case Process.whereis(:pg) do
#          nil -> Enum.each(subscribers, fn sub -> send(Base.decode64!(sub) |> :erlang.binary_to_term, {:scenario_stopped}) end)
#          _ -> :ok
#        end


        DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] ->
        Logger.error("COULD NOT FIND SCENARIO WITH id '#{inspect(scenario_id)}'")
        {:error, :not_found}
    end
  end

  def stop_all() do
    Enum.each(DynamicSupervisor.which_children(__MODULE__),
      fn {_, child_pid, _, _} ->
        DynamicSupervisor.terminate_child(__MODULE__, child_pid)
      end )
  end

  def active_scenarios do
    DynamicSupervisor.which_children(__MODULE__)
  end
end
