defmodule GeneticsEngine.Sim.SimController do
  @moduledoc false

  use GenServer
  require Logger
  require DirectDebug

  alias GeneticsEngine.Sim.UdpConnectionServer
  alias GeneticsEngine.Sim.ScenarioSupervisor
  alias GeneticsEngine.Sim.Scenario

  @sim_controller_name :SimController
  @sim_ping_interval 2500

  #============================================= API ============================================= #

  def current_sim_state do
    GenServer.call(@sim_controller_name, :current_sim_state)
  end


  def start_scenario(params) do
    GenServer.call(@sim_controller_name, {:start_scenario, params})
  end

  def handle_sim_started(params) do
    GenServer.cast(@sim_controller_name, {:sim_ready, params})
  end

  def on_scenario_complete(scenario_id) do
    DirectDebug.section("#{inspect(scenario_id)} - COMPLETE!!")
    DirectDebug.warning("active scenarios: #{inspect ScenarioSupervisor.active_scenarios()}")
    GenServer.call(@sim_controller_name, {:complete_scenario, scenario_id})
  end

  def stop_scenario(scenario_id) do
    GenServer.call(@sim_controller_name, {:stop_scenario, scenario_id})
  end

  def on_sim_stopped(params) do
    GenServer.cast(@sim_controller_name, {:sim_stopped, params})
  end

  def panic do
    GenServer.call(@sim_controller_name, :panic)
  end

  #======================================= IMPLEMENTATION ======================================== #

  def start_link(_opts) do
    name = @sim_controller_name
    GenServer.start_link(__MODULE__, [name: name], name: name)
  end

  @impl true
  def init([name: name]) do
    Logger.info("starting sim controller...")
    :pg.join(:sim_events, self())
    Process.send_after(self(), :ping_sim, @sim_ping_interval)
    {:ok, %{
      name: name,
      simulator_running: false,
      scenarios: [],
      scenario_in_progress: false,
      # Set initial value to Unix epoch (1970-01-01) so that current time will always be greater than this on first comparison
      last_sim_event_time: DateTime.from_unix!(0)
    }}
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
    UdpConnectionServer.send_start_scenario(params)
    {:reply, :ok, %{state | simulator_running: true, scenario_in_progress: true}}
  end

  @impl true
  def handle_call(:stop_scenario, _from, state) do
    DirectDebug.info("#{state.name} - handling generic stop_scenario call")
    UdpConnectionServer.send_stop_scenario(nil)
    {:reply, :ok, %{state | simulator_running: false, scenario_in_progress: false}}
  end

  @impl true
  def handle_call({:scenario_completed, _scenario_id}, _from, state) do
#    UdpConnectionServer.send_stop_scenario(scenario_id)
    {:reply, :ok, state}
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
    resp = GeneticsEngine.Sim.ScenarioSupervisor.stop_all()
    UdpConnectionServer.panic
    DirectDebug.info("#{state.name} - panic result: #{inspect(resp)}")
    {:reply, resp,%{state | scenario_in_progress: false}}
  end

  @impl true
  def handle_call(:complete_scenario, _from, state) do
    DirectDebug.error("#{state.name} -  COMPLETING SCENARIO")
    {:reply, :ok ,%{state | scenario_in_progress: false}}
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
    Scenario.destroy_all()
    {:noreply, %{state | simulator_running: false}}
  end

  def handle_cast(msg, state) do
    :logger.warning("#{state.name} - unknown cast #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:sim_events, event, _payload}, state) do
    # Update last event time to track when we last heard from the simulator
    {:noreply, %{state | last_sim_event_time: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:ping_sim, state) do
    # Only ping if we haven't heard from the simulator in @sim_ping_interval milliseconds
    current_time = DateTime.utc_now()
    time_diff_ms = DateTime.diff(current_time, state.last_sim_event_time, :millisecond)

    if time_diff_ms >= @sim_ping_interval do
      UdpConnectionServer.ping_sim()
    end

    # schedule the next ping!
    Process.send_after(self(), :ping_sim, @sim_ping_interval)
    {:noreply, state}
  end

  #=========================================== INTERNAL ========================================== #


end
