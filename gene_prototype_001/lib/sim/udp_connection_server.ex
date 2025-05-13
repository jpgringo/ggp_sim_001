defmodule GenePrototype0001.Sim.UdpConnectionServer do
  use GenServer
  require Logger

  def start_link(opts) do
    Logger.info("Starting UDP server...")
    GenServer.start_link(__MODULE__, opts, name: :SimUdpConnector)
  end

  @impl true
  def init(opts) do
    send_ip = Keyword.get(opts, :send_ip, "127.0.0.1")
    send_port = Keyword.get(opts, :send_port, 7401)
    receive_port = Keyword.fetch!(opts, :receive_port)
    {:ok, socket} = :gen_udp.open(receive_port, [:binary, active: true, reuseaddr: true])
    Logger.info("UDP server listening on port #{receive_port}")
    {:ok, %{socket: socket, receive_port: receive_port, send_ip: send_ip, send_port: send_port, sim_ready: false}}
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, state) do
    client_string = "#{:inet.ntoa(ip)}:#{port}"
    new_state = case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params}} ->
        Logger.info("Received '#{method}' request from #{client_string} with params: #{inspect(params)}")
        case handle_rpc_call(method, params, state) do
          {:noreply, updated_state} -> updated_state
          _ -> state
        end
      {:ok, _} ->
        Logger.info("Invalid JSON-RPC request from #{client_string}: #{inspect(data)}")
        state
      {:error, _} ->
        Logger.info("Bad packet received from #{client_string}")
        state
    end
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:sim_ready?, _from, state) do
    {:reply, state.sim_ready, state}
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
  def handle_call({:send_command, command, params}, _from, state = %{socket: socket, send_ip: send_ip, send_port: send_port}) do
    notification = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => command,
      "params" => params
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
  defp handle_rpc_call("sim_ready", params, state) do
    Logger.info("Sim ready!!: #{inspect(params)}")
    GenServer.cast(:SimController, {:sim_ready, params})
    {:noreply, %{state | sim_ready: true}}
  end

  defp handle_rpc_call("sim_stopping", params, state) do
    Logger.info("Sim stopping!!: #{inspect(params)}")
    # Forward batch to WebSocket clients
    GenServer.cast(:SimController, {:sim_stopped, params})
    GenePrototype0001.SimulationSocket.broadcast_stop(params)

    {:noreply, %{state | sim_ready: false}}
  end

  defp handle_rpc_call("agent_created", %{"id" => agent_id} = params, state) do
    Logger.info("Agent created: #{inspect(params)}")
    case GenePrototype0001.Onta.OntosSupervisor.start_ontos(agent_id, params) do
      {:ok, pid} ->
        Logger.info("Started Ontos for agent #{agent_id} with pid #{inspect(pid)}")
      {:error, reason} ->
        Logger.error("Failed to start Ontos for agent #{agent_id}: #{inspect(reason)}")
    end
    {:noreply, state}
  end

  defp handle_rpc_call("agent_destroyed", %{"id" => agent_id}, state) do
    case Registry.lookup(GenePrototype0001.Onta.OntosRegistry, agent_id) do
      [{pid, _}] ->
        Logger.info("Terminating Ontos for agent #{agent_id}")
        GenePrototype0001.Onta.OntosSupervisor.terminate_ontos(pid)
      [] ->
        Logger.warning("No Ontos found for agent #{agent_id}")
    end
    {:noreply, state}
  end

  defp handle_rpc_call("sensor_data", %{"agent" => agent_id, "data" => data}, state) do
    case Registry.lookup(GenePrototype0001.Onta.OntosRegistry, agent_id) do
      [{_pid, _}] ->
        GenePrototype0001.Onta.Ontos.handle_sensor_data(agent_id, data)
      [] ->
        Logger.warning("Received sensor data for unknown agent #{agent_id}")
    end
    {:noreply, state}
  end

  defp handle_rpc_call("batch", batch, state) do
    Logger.info("received batch: #{inspect(batch)}")

    # Forward batch to WebSocket clients
    GenePrototype0001.SimulationSocket.broadcast_batch(batch)

    group_by_agent(batch)
    |> Enum.each(fn entry ->
      case Registry.lookup(GenePrototype0001.Onta.OntosRegistry, entry["agent"]) do
        [{_pid, _}] ->
          GenServer.cast(_pid, {:sensor_batch, entry["events"]})
        [] ->
          Logger.warning("Received sensor data for unknown agent #{entry["agent"]}")
      end
    end)
    {:noreply, state}
  end

  defp handle_rpc_call("scenario_stopped", params, state) do
    Logger.info("Sim stopping!!: #{inspect(params)}")
    # Forward batch to WebSocket clients
    GenePrototype0001.SimulationSocket.broadcast_stop(params)

    {:noreply, %{state | sim_ready: true}}
  end



  defp handle_rpc_call(method, _params, state) do
    Logger.warning("Unknown method received: #{inspect(method)}")
    {:noreply, state}
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
end
