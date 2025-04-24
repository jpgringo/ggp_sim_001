defmodule GenePrototype0001.UdpConnectionServer do
  use GenServer
  require Logger

  def start_link(opts) do
    Logger.info("Starting UDP server...")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true, reuseaddr: true])
    Logger.info("UDP server listening on port #{port}")
    {:ok, %{socket: socket, port: port}}
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, state) do
    Logger.info("Received UDP message from #{:inet.ntoa(ip)}:#{port}: #{inspect(data)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{socket: socket}) do
    :gen_udp.close(socket)
    :ok
  end
end
