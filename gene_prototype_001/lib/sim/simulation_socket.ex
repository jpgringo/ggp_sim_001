defmodule GenePrototype0001.SimulationSocket do
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

  def broadcast_stop(params) do
    Registry.dispatch(SimulationSocketRegistry, "simulation", fn entries ->
      Logger.debug("BROADCASTING STOP!!")
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
  def handle_info(_info, state) do
    {:ok, state}
  end

  @impl WebSock
  def terminate(_reason, _state) do
    Logger.info("WebSocket connection closed")
    :ok
  end
end
