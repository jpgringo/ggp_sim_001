defmodule GenePrototype0001.Sim.SimController do
  @moduledoc false

  use GenServer
  require Logger


  #============================================= API ============================================= #

  def handle_sim_start(params) do
    GenServer.cast(:SimController, {:sim_ready, params})
  end

  #======================================= IMPLEMENTATION ======================================== #

  def start_link(_opts) do
    name = :SimController
    GenServer.start_link(__MODULE__, [name: name], name: name)
  end

  @impl true
  def init([name: name]) do
    Logger.info("starting sim controller...")
    {:ok, %{name: name, simulator_running: false, scenarios: [], scenario_in_progress: false}}
  end

  @impl true
  def handle_call(:current_sim_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:start_scenario, _params}, _from, %{scenario_in_progress: true} = state) do
    {:reply, {:error, :scenario_in_progress}, state}
  end

  @impl true
  def handle_call({:start_scenario, params}, _from, state) do
    :logger.debug("#{state.name} - handling start_scenario call - param: #{inspect(params)}")
    GenServer.call(:SimUdpConnector, {:send_command, "start_scenario", params})
    {:reply, :ok, %{state | simulator_running: true, scenario_in_progress: true}}
  end

  @impl true
  def handle_call(:stop_scenario, _from, state) do
    DirectDebug.info("#{state.name} - handling generic stop_scenario call")
    GenServer.call(:SimUdpConnector, {:send_command, "stop_scenario", nil})
    {:reply, :ok, %{state | simulator_running: false, scenario_in_progress: false}}
  end

  @impl true
  def handle_call({:stop_scenario, scenario_id}, _from, state) do
    DirectDebug.info("#{state.name} - handling stop_scenario call for scenario #{scenario_id}")
    result = GenServer.call(:SimUdpConnector, {:send_command, "stop_scenario", scenario_id})
    DirectDebug.info("#{state.name} - stop_scenario result: #{inspect(result)}")
    {:reply, result, %{state | simulator_running: false, scenario_in_progress: false}}
  end

  @impl true
  def handle_call(:panic, _from, state) do
    DirectDebug.info("#{state.name} - handling panic call")
    resp = GenePrototype0001.Sim.ScenarioSupervisor.stop_all()
    GenServer.call(:SimUdpConnector, {:send_command, "panic", nil})
    DirectDebug.info("#{state.name} - panic result: #{inspect(resp)}")
    {:reply, resp,%{state | scenario_in_progress: false}}
  end

  @impl true
  def handle_call(msg, from, state) do
    :logger.warning("#{state.name} - unknown call #{inspect(msg)} from #{inspect(from)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:sim_ready, %{"scenarios" => scenarios}}, state) do
    :logger.debug("SimController - marking as LIVE and adding scenarios to state")
    {:noreply, %{state | simulator_running: true, scenarios: scenarios}}
  end

  def handle_cast({:sim_stopped, _params}, state) do
    :logger.debug("SimController - marking as STOPPED")
    {:noreply, %{state | simulator_running: false}}
  end

  def handle_cast(msg, state) do
    :logger.warning("#{state.name} - unknown cast #{inspect(msg)}")
    {:noreply, state}
  end
end
