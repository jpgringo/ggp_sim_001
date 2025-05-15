defmodule GenePrototype0001.Sim.SimController do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(_opts) do
    name = :SimController
    GenServer.start_link(__MODULE__, [name: name], name: name)
  end

  def init([name: name]) do
    Logger.info("starting sim controller...")
    {:ok, %{name: name, simulator_running: false, scenarios: [], scenario_in_progress: false}}
  end

  def handle_call(:current_sim_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:start_scenario, params}, _from, %{scenario_in_progress: true} = state) do
    {:reply, {:error, :scenario_in_progress}, state}
  end

  def handle_call({:start_scenario, params}, _from, state) do
    Logger.debug("#{state.name} - handling start_sim call - param: #{inspect(params)}")
    GenServer.call(:SimUdpConnector, {:send_command, "start_scenario", params})
    {:reply, :ok, %{state | simulator_running: true, scenario_in_progress: true}}
  end

  @impl true
  def handle_call(:stop_scenario, _from, state) do
    GenServer.call(:SimUdpConnector, {:send_command, "stop_scenario", nil})
    {:reply, :ok, %{state | simulator_running: false, scenario_in_progress: false}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:sim_ready, %{"scenarios" => scenarios}}, state) do
    Logger.debug("SimController - marking as LIVE and adding scenarios to state")
    {:noreply, %{state | simulator_running: true, scenarios: scenarios}}
  end

  def handle_cast({:sim_stopped, _params}, state) do
    Logger.debug("SimController - marking as STOPPED")
    {:noreply, %{state | simulator_running: false}}
  end

  def handle_cast(_msg, state) do
    Logger.warn("#{state.name} - unknown cast #{inspect(_msg)}")
    {:noreply, state}
  end
end
