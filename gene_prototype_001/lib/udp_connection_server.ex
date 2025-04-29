defmodule GenePrototype0001.UdpConnectionServer do
  use GenServer
  require Logger

  # Client API
  def hello_world do
    GenServer.call(__MODULE__, :hello_world)
  end

  def send_actuator_data(agent_id, data) do
    GenServer.call(__MODULE__, {:send_actuator_data, agent_id, data})
  end

  def start_link(opts) do
    Logger.info("Starting UDP server...")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    send_ip = Keyword.get(opts, :send_ip, "127.0.0.1")
    send_port = Keyword.get(opts, :send_port, 7401)
    receive_port = Keyword.fetch!(opts, :receive_port)
    {:ok, socket} = :gen_udp.open(receive_port, [:binary, active: true, reuseaddr: true])
    Logger.info("UDP server listening on port #{receive_port}")
    {:ok, %{socket: socket, receive_port: receive_port, send_ip: send_ip, send_port: send_port}}
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, state) do
    client_string = "#{:inet.ntoa(ip)}:#{port}"
    case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params}} ->
        Logger.info("Received '#{method}' request from #{client_string} with params: #{inspect(params)}")
        handle_rpc_call(method, params, state)
      {:ok, _} ->
        Logger.info("Invalid JSON-RPC request from #{client_string}: #{inspect(data)}")
      {:error, _} ->
        Logger.info("Bad packet received from #{client_string}")
    end
    {:noreply, state}
  end

  @impl true
  def handle_call(:hello_world, _from, state = %{socket: socket, send_ip: send_ip, send_port: send_port}) do
    notification = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "message",
      "params" => ["hello from Elixir!", "turtle_01", 3, [-5, 2.2, 0, 0, -1.8, 4, 0]]
    })
    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, "Hello from UDP server!", state}
  end

  @impl true
  def handle_call({:send_actuator_data, agent_id, data}, _from, state = %{socket: socket, send_ip: send_ip, send_port: send_port}) do
    notification = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "actuator_data",
      "params" => %{
        "agent" => agent_id,
        "data" => data
      }
    })
    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, %{socket: socket}) do
    :gen_udp.close(socket)
    :ok
  end

  # Private functions
  defp handle_rpc_call("agent_created", %{"id" => agent_id} = params, state) do
    Logger.info("Agent created: #{inspect(params)}")
    case GenePrototyp0001.Onta.OntosSupervisor.start_ontos(agent_id, params) do
      {:ok, pid} ->
        Logger.info("Started Ontos for agent #{agent_id} with pid #{inspect(pid)}")
      {:error, reason} ->
        Logger.error("Failed to start Ontos for agent #{agent_id}: #{inspect(reason)}")
    end
    {:noreply, state}
  end

  defp handle_rpc_call("agent_destroyed", %{"id" => agent_id}, state) do
    case Registry.lookup(GenePrototyp0001.Onta.OntosRegistry, agent_id) do
      [{pid, _}] ->
        Logger.info("Terminating Ontos for agent #{agent_id}")
        GenePrototyp0001.Onta.OntosSupervisor.terminate_ontos(pid)
      [] ->
        Logger.warning("No Ontos found for agent #{agent_id}")
    end
    {:noreply, state}
  end

  defp handle_rpc_call("sensor_data", %{"agent" => agent_id, "data" => data}, state) do
    case Registry.lookup(GenePrototyp0001.Onta.OntosRegistry, agent_id) do
      [{_pid, _}] ->
        GenePrototyp0001.Onta.Ontos.handle_sensor_data(agent_id, data)
      [] ->
        Logger.warning("Received sensor data for unknown agent #{agent_id}")
    end
    {:noreply, state}
  end

  defp handle_rpc_call(method, _params, state) do
    Logger.warning("Unknown method received: #{inspect(method)}")
    {:noreply, state}
  end
end
