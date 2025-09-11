defmodule GeneticsEngine.SimulationSocket do
  @behaviour WebSock

  require Logger

  def broadcast_batch(batch) do
    Registry.dispatch(SimulationSocketRegistry, "simulation", fn entries ->
      message = Jason.encode!(%{type: "batch", data: batch})
      for {pid, _} <- entries do
        Process.send(pid, {:send_message, message}, [])
      end
    end)
  end

  def broadcast_start(params) do
    # Logger.debug("BROADCASTING START!!")
    DirectDebug.info("BROADCASTING START!! #{inspect(params)}")
    Registry.dispatch(SimulationSocketRegistry, "simulation", fn entries ->
      message = Jason.encode!(%{type: "start", data: params})
      for {pid, _} <- entries do
        Process.send(pid, {:send_message, message}, [])
      end
    end)
  end

  def broadcast_stop(params) do
    Logger.debug("BROADCASTING STOP!!")
    Registry.dispatch(SimulationSocketRegistry, "simulation", fn entries ->
      message = Jason.encode!(%{type: "stop", data: params})
      for {pid, _} <- entries do
        Process.send(pid, {:send_message, message}, [])
      end
    end)
  end

  @impl WebSock
  def init(_args) do
    Logger.info("WebSocket connection established")
    {:ok, _} = Registry.register(SimulationSocketRegistry, "simulation", {})
    :pg.join(:scenario_events, self())
    :pg.join(:ontos_events, self())
    {:ok, %{}}
  end

  @impl WebSock
  def handle_in({_text, _opts}, state) do
    {:ok, state}
  end

  @impl WebSock
  def handle_info({:send_message, message}, state) do
    {:push, {:text, message}, state}
  end

  @impl WebSock
  def handle_info({:ontos_events, :actuator_sent, data}, state) do
    DirectDebug.warning("handling :ontos_event `:actuator_sent`. data: #{inspect(data)}")
    message = Jason.encode!(%{type: "actuator_sent", data: data})
    {:push, {:text, message}, state}
  end

  @impl WebSock
  def handle_info({:simulation_run_started, data}, state) do
    DirectDebug.error("SimulationSocket received simulation_run_started: #{inspect(data)}")
    broadcast_start(data)
    {:ok, state}
  end

  @impl WebSock
  def handle_info(info, state) do
    DirectDebug.warning("SimulationSocket received unknown message: #{inspect(info)}")
    {:ok, state}
  end

  @impl WebSock
  def terminate(_reason, _state) do
    Logger.info("WebSocket connection closed")
    :ok
  end


end
