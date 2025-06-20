defmodule GenePrototype0001.Sim.Scenario do
  @moduledoc false

  use GenServer
  require Logger
  require DirectDebug

  alias GenePrototype0001.Onta.Ontos
  alias GenePrototype0001.Reports.ScenarioRunReportServer

  #============================================= API ============================================= #

  def get_onta(scenario_pid) do
    GenServer.call(scenario_pid, :get_onta)
  end

  def route_sensor_data_batch(scenario, entries) do
    case Registry.lookup(GenePrototype0001.Sim.ScenarioRegistry, scenario) do
      [{scenario_pid, _}] ->
        DirectDebug.extra("Scenario - found scenario (#{inspect(scenario_pid)})")
        GenServer.cast(scenario_pid, {:sensor_batch, entries})
      [] ->
        DirectDebug.warning("Received sensor data for unknown scenario #{scenario}", true)
    end
  end

  #======================================= IMPLEMENTATION ======================================== #

  def start_link(scenario_name, unique_id, agents) do
    Logger.debug("Scenario starting '#{scenario_name}/#{unique_id} with agents: #{inspect(agents)}")
    unique_name = "#{scenario_name || "unnamed"}_#{unique_id}"
    opts = %{id: unique_id, name: unique_name, scenario_name: scenario_name, agents: agents}
    GenServer.start_link(__MODULE__, opts, name: via_tuple(unique_id))
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true) # ESSENTIAL to ensure terminate/2 runs
    DirectDebug.info("Initializing scenario: #{opts.name}") # bold, underline, yellow

    # NOW start OntaSupervisor
    case GenePrototype0001.Onta.OntosSupervisor.start_link([name: "#{opts.name}_ontasup"]) do
      {:ok, ontasup_pid} ->
        init_onta(opts.id, ontasup_pid, opts.agents)
        state = Map.put(opts, :ontasup, ontasup_pid)
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to start OntaSupervisor: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_name, _from, state) do
    {:reply, {:ok, state.name}, state}
  end

  @impl true
  def handle_call(:get_onta, _from, state) do
    supervised_onta = Enum.map(DynamicSupervisor.which_children(state.ontasup), fn {_, pid, _, _} -> pid end)
    {:reply, {:ok, supervised_onta}, state}
  end

  @impl true
  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:sensor_batch, batch}, state) do
    DirectDebug.info("#{state.name} received :sensor_batch: #{inspect(batch)}")
    group_by_agent(batch)
    |> Enum.each(fn %{"agent" => agent, "events" => events} ->
      agent_id = "#{state.id}_#{agent}"
      DirectDebug.info("Scenario '#{state.id}' will send event batch to ontos #{inspect(agent_id)}: #{inspect(events)}")
      case Registry.lookup(GenePrototype0001.Onta.OntosRegistry, agent_id) do
        [{ontos_pid, _}] ->
          DirectDebug.extra("Found Ontos #{inspect(ontos_pid)}")
          Ontos.handle_sensor_data(ontos_pid, events)

        [] ->
          DirectDebug.warning("Could NOT find agent #{agent_id}")
      end
    end)
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    :logger.warning("#{state.name} received unknown cast: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    DirectDebug.info("Terminating scenario #{state.name} with reason: #{inspect(reason)}. state: #{inspect(state)}", true)
    # Stop the OntaSupervisor; since we started it directly, we need to exit it explicitly
    %{scenario_name: resource_id, id: run_id, agents: agents} = state
    agent_summaries = Enum.map(agents, fn agent ->
      Map.merge(agent, %{"events" => %{"actuators" => Ontos.get_event_count("#{state.id}_#{agent["id"]}", :actuator)}})
    end)
    ScenarioRunReportServer.submit_report(NaiveDateTime.local_now() |> NaiveDateTime.to_iso8601(), resource_id, run_id, agent_summaries)
    if Process.whereis(:pg) != nil do
      Enum.each(:pg.get_members(:scenario_events), & send(&1, {:scenario_terminated, state}))
    end
    Process.exit(state.ontasup, :shutdown)
    :ok
  end

  defp init_onta(unique_id, ontasup, agents) do
    DirectDebug.info("Scenario '#{unique_id} will init agents #{inspect(agents)}")
    for %{"id" => agent_id} <- agents do
      opts = [scenario_id: unique_id, available_actuators: 1, numina: [GenePrototype0001.Numina.BasicMotionNumen]]
      spec = {GenePrototype0001.Onta.Ontos, {agent_id, opts}}
      case DynamicSupervisor.start_child(ontasup, spec) do
        {:ok, pid} ->
          DirectDebug.info("Scenario '#{unique_id}' - successfully started Ontos with PID #{inspect(pid)}", true)

        {:error, {:already_started, pid}} ->
          DirectDebug.warning("Scenario '#{unique_id}' - ontos already started with PID #{inspect(pid)}", true)

        {:error, reason} ->
          DirectDebug.error("Scenario '#{unique_id}' - failed to start Ontos: #{inspect(reason)}", true)
      end
    end
  end

  def group_by_agent(batch) do
    batch
    |> Enum.group_by(fn entry -> entry["agent"] end)
    |> Enum.map(fn {agent, entries} ->
      %{
        "agent" => agent,
        "events" => Enum.map(entries, fn entry -> entry["data"] end)
      }
    end)
    |> Enum.sort_by(fn %{"agent" => agent} ->
      # Keep first occurrence order of each agent
      Enum.find_index(batch, fn x -> x["agent"] == agent end)
    end)
  end


  defp via_tuple(scenario_name) do
    {:via, Registry, {GenePrototype0001.Sim.ScenarioRegistry, scenario_name}}
  end
end
