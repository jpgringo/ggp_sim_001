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
    client_string = "#{:inet.ntoa(ip)}:#{port}"
    case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params}} ->
        Logger.info("Received '#{method}' request from #{client_string} with params: #{inspect(params)}")
      {:ok, _} ->
        Logger.info("Invalid JSON-RPC request from #{client_string}: #{inspect(data)}")
      {:error, _} ->
        Logger.info("Bad packet received from #{client_string}")
    end
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{socket: socket}) do
    :gen_udp.close(socket)
    :ok
  end
end
