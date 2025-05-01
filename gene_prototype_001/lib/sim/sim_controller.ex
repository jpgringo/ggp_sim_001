defmodule GenePrototype0001.Sim.SimController do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: :SimController)
  end

  def init(_opts) do
    Logger.info("starting sim controller...")
    {:ok, %{}}
  end

  def start_sim(player_count) do
    Logger.debug("Would start simulator...")
    GenePrototype0001.Sim.UdpConnectionServer.send_command("start_sim", %{player_count: player_count})
  end

  def stop_sim() do
    Logger.debug("Stopping simulator...")
    GenePrototype0001.Sim.UdpConnectionServer.send_command("stop_sim", [])
  end

  def start_sim() do
    Logger.debug("Would start simulator...")
    GenePrototype0001.Sim.UdpConnectionServer.send_command("start_sim", %{player_count: 1})
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end
end
