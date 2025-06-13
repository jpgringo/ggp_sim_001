defmodule GenePrototype0001.Sim.UdpConnectionServer do
  use GenServer
  require Logger
  require DirectDebug

  @sim_connector_name :SimUdpConnector

  def start_link(opts) do
    Logger.info("Starting UDP server...")
    GenServer.start_link(__MODULE__, opts, name: @sim_connector_name)
  end

  @impl true
  def init(opts) do
    send_ip = Keyword.get(opts, :send_ip, "127.0.0.1")
    send_port = Keyword.get(opts, :send_port, 7401)
    receive_port = Keyword.fetch!(opts, :receive_port)
    name = @sim_connector_name
    {:ok, socket} = :gen_udp.open(receive_port, [:binary, active: true, reuseaddr: true])
    DirectDebug.info("#{name} - UDP server listening on port #{receive_port}")
    {:ok, %{name: name, socket: socket, receive_port: receive_port, send_ip: send_ip, send_port: send_port, sim_ready: false}}
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data, subscribers}, state) do
    DirectDebug.info("#{@sim_connector_name} - HANDLING UDP INFO!! #{inspect(data)}}")
    client_string = "#{:inet.ntoa(ip)}:#{port}"
    new_state = case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params}} ->
        DirectDebug.info("#{@sim_connector_name} - Received '#{method}' request from #{client_string} with params: #{inspect(params)}", true)
        case handle_rpc_call(method, Map.merge(%{"subscribers" => subscribers}, params), state) do
          {:noreply, updated_state} -> updated_state
          _ -> state
        end
      {:ok, _} ->
        :logger.info("Invalid JSON-RPC request from #{client_string}: #{inspect(data)}")
        state
      {:error, _err} ->
        :logger.info("Bad packet received from #{client_string}: #{inspect(data)}")
        state
      result ->
        :logger.warning("unknown result attempting to decode JSON: #{inspect(result)}")
        state
    end
    {:noreply, new_state}
  end

  def handle_info({:udp, socket, ip, port, data}, state) do
    send(self(), {:udp, socket, ip, port, data, []})
    {:noreply, state}
  end

    @impl true
  def handle_info(msg, state) do
    :logger.warning(":SimUdpConnector received unknown message: #{inspect(msg)}")
    {:noreply, state}
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
    DirectDebug.info(":SimUdpConnector - :send_actuator_data. ip=#{send_ip}; port=#{send_port}; notification: #{inspect(notification)}")
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

  #  ============================== SIM STATE HANDLERS ============================
  defp handle_rpc_call("sim_ready", params, state) do
    Logger.info("#{state.name} - Sim ready!!: #{inspect(params)}")
    GenServer.cast(:SimController, {:sim_ready, params})
    GenePrototype0001.SimulationSocket.broadcast_start(params)
    {:noreply, %{state | sim_ready: true}}
  end

  defp handle_rpc_call("sim_stopping", params, state) do
    Logger.info("Sim stopping!!: #{inspect(params)}")
    # Forward batch to WebSocket clients
    GenServer.cast(:SimController, {:sim_stopped, params})
    GenePrototype0001.SimulationSocket.broadcast_stop(params)

    {:noreply, %{state | sim_ready: false}}
  end

  #  ============================== SCENARIO STATE HANDLERS ============================
  defp handle_rpc_call("scenario_started", params, state) do
    DirectDebug.info("#{@sim_connector_name} - Handling scenario started!!: #{inspect(params)}")
    GenePrototype0001.Sim.ScenarioSupervisor.start_scenario(params)
    {:noreply, %{state | sim_ready: true}}
  end

  defp handle_rpc_call("scenario_stopped", params, state) do
    Logger.info("Scenario stopped!!: #{inspect(params)}")
    GenePrototype0001.Sim.ScenarioSupervisor.stop_scenario(params["id"])
    # Forward batch to WebSocket clients
    GenePrototype0001.SimulationSocket.broadcast_stop(params)

    {:noreply, %{state | sim_ready: true}}
  end

  #  ============================== AGENT STATE HANDLERS ============================
  defp handle_rpc_call("agent_created", %{"id" => _agent_id}, state) do
    # this is emitted by sims, but we don't need to handle it at this time (onta are created when the scenario is initialize)
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

  #  ============================== SENSOR UPDATE HANDLERS ============================
  defp handle_rpc_call("sensor_data", %{"agent" => agent_id, "data" => data}, state) do
    case Registry.lookup(GenePrototype0001.Onta.OntosRegistry, agent_id) do
      [{_pid, _}] ->
        GenePrototype0001.Onta.Ontos.handle_sensor_data(agent_id, data)
      [] ->
        Logger.warning("1. Received sensor data for unknown agent #{agent_id}")
    end
    {:noreply, state}
  end

  defp handle_rpc_call("batch", batch, state) do
    DirectDebug.extra("#{state.name} - handling batch: #{inspect(batch)}")

    # Forward batch to WebSocket clients
    GenePrototype0001.SimulationSocket.broadcast_batch(batch)

    subscribers = Map.get(batch, "subscribers", [])

    group_by_scenario(batch["sensor_data"])
    |> Enum.each(fn scenario ->
      DirectDebug.extra("#{state.name} - extracted data from batch for scenario '#{inspect(scenario)}'")
      case Registry.lookup(GenePrototype0001.Sim.ScenarioRegistry, scenario["scenario"]) do
        [{pid, _}] ->
          DirectDebug.extra("#{state.name} - found scenario (#{inspect(pid)})")
          GenServer.cast(pid, {:sensor_batch, scenario["entries"], subscribers})
        [] ->
          DirectDebug.warning("Received sensor data for unknown scenario #{scenario["scenario"]}", true)
      end
    end)

    # TODO: delete this, it should ALWAYS be handled through Scenarios
#    group_by_agent(batch)
#    |> Enum.each(fn entry ->
#      case Registry.lookup(GenePrototype0001.Onta.OntosRegistry, entry["agent"]) do
#        [{_pid, _}] ->
#          GenServer.cast(_pid, {:sensor_batch, entry["events"]})
#        [] ->
#          Logger.warning("2. Received sensor data for unknown agent #{entry["agent"]}")
#      end
#    end)
    {:noreply, state}
  end

  #  ============================== 'BACKSTOP' HANDLER ============================
  defp handle_rpc_call(method, _params, state) do
    Logger.warning("#{state.name} - Unknown method received: #{inspect(method)}")
    {:noreply, state}
  end

  #  ============================== HELPER FUNCTIONS ============================
  def group_by_scenario(batch) do
    batch
      |> Enum.group_by(fn entry -> entry["scenario"] end)
      |> Enum.map(fn {scenario, entries} ->
        %{
        "scenario" => scenario,
        "entries" => Enum.map(entries, &Map.delete(&1, "scenario"))
        }
    end)
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
