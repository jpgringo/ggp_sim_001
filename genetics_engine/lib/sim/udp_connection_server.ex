defmodule GeneticsEngine.Sim.UdpConnectionServer do
  use GenServer
  require Logger
  require DirectDebug

  alias GeneticsEngine.Sim.SimController
  alias GeneticsEngine.SimulationSocket
  alias GeneticsEngine.Sim.Scenario
  alias GeneticsEngine.Sim.ScenarioSupervisor

  @sim_connector_name :SimUdpConnector

  #============================================= API ============================================= #

  def sim_ready? do
    GenServer.call(@sim_connector_name, :sim_ready)
  end

  def ping_sim do
    GenServer.cast(@sim_connector_name, :ping_sim)
  end

  def send_actuator_data(agent_id, actuator_data) do
    GenServer.call(@sim_connector_name, {:send_actuator_data,
      agent_id,
      actuator_data}
    )
  end

  def send_start_scenario(opts) do
    GenServer.call(@sim_connector_name, {:send_command, "start_scenario", opts})
  end

  def send_stop_scenario(opts) do
    GenServer.call(@sim_connector_name, {:send_command, "stop_scenario", opts})
  end

  def panic do
    GenServer.call(@sim_connector_name, {:send_command, "panic", nil})
  end

  #======================================= IMPLEMENTATION ======================================== #

  def start_link(opts) do
    Logger.info("Starting UDP server...")
    GenServer.start_link(__MODULE__, opts, name: @sim_connector_name)
  end

  @impl true
  def init(opts) do
    DirectDebug.info("initing UDP server with opts #{inspect(opts)}")
    send_ip = Keyword.get(opts, :send_ip, "127.0.0.1")
    send_port = Keyword.get(opts, :send_port, 7401)
    receive_port = Keyword.fetch!(opts, :receive_port)
    name = @sim_connector_name
    {:ok, socket} = :gen_udp.open(receive_port, [:binary, active: true, reuseaddr: true])
    DirectDebug.info("#{name} - UDP server listening on port #{receive_port}")
    {:ok, %{name: name, socket: socket, receive_port: receive_port, send_ip: send_ip, send_port: send_port, sim_ready: false}}
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, state) do
    DirectDebug.extra("#{@sim_connector_name} - HANDLING UDP INFO!! #{inspect(data)}}")
    client_string = "#{:inet.ntoa(ip)}:#{port}"
    new_state = case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params}} ->
        DirectDebug.info("#{@sim_connector_name} - Received '#{method}' request from #{client_string} with params: #{inspect(params)}", true)
        case handle_rpc_call(method, params, state) do
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

  @impl true
  def handle_info(msg, state) do
    :logger.warning(":SimUdpConnector received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast(:ping_sim, state = %{socket: socket, send_ip: send_ip, send_port: send_port}) do
    DirectDebug.info("UdpConnectionServer will ping sim...")
    notification = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "sim_ping",
      "params" => nil
    })
    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:noreply, state}
  end

  @impl true
  def handle_call(:sim_ready, _from, state) do
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
    SimController.handle_sim_started(params)
#    SimulationSocket.broadcast_start(params)
    {:noreply, %{state | sim_ready: true}}
  end

  defp handle_rpc_call("sim_pong", params, state) do
    Logger.info("#{state.name} - Sim ready!!: #{inspect(params)}")
    SimController.handle_sim_started(params)
    case Process.whereis(:pg) do
      nil -> DirectDebug.error(":pg is not running")
      _ ->
        Enum.each(:pg.get_members(:sim_events), & send(&1, {:sim_events, :pong, params}))
        :ok
    end
    {:noreply, %{state | sim_ready: true}}
  end

  defp handle_rpc_call("sim_stopping", params, state) do
    Logger.info("Sim stopping!!: #{inspect(params)}")
    # Forward batch to WebSocket clients
    SimController.on_sim_stopped(params)
    SimulationSocket.broadcast_stop(params)

    {:noreply, %{state | sim_ready: false}}
  end

  #  ============================== SCENARIO STATE HANDLERS ============================
  defp handle_rpc_call("scenario_started", params, state) do
    DirectDebug.info("#{@sim_connector_name} - Handling scenario started!!: #{inspect(params)}")
    scenario = ScenarioSupervisor.start_scenario(params)
    DirectDebug.warning("scenario initialized: #{inspect(scenario)}/#{inspect(Process.whereis(:pg))}")
    if Mix.env() == :test do
      case Process.whereis(:pg) do
        nil -> :logger.error(":pg is not running in the test environment")
        pg_pid ->
          DirectDebug.warning(":pg is running! #{inspect(pg_pid)}... #{inspect(:pg.get_members(:scenario_events))}")
          :ok
      end
    end
    {:noreply, %{state | sim_ready: true}}
  end

  defp handle_rpc_call("scenario_stopped", params, state) do
    DirectDebug.info("#{state.name} - Handling scenario_stopped!!: #{inspect(params)}")
    ScenarioSupervisor.stop_scenario(params["id"])

    # Forward batch to WebSocket clients
    SimulationSocket.broadcast_stop(params)

    {:noreply, %{state | sim_ready: true}}
  end

  #  ============================== AGENT STATE HANDLERS ============================
  defp handle_rpc_call("agent_created", %{"id" => _agent_id}, state) do
    # this is emitted by sims, but we don't need to handle it at this time (onta are created when the scenario is initialize)
    {:noreply, state}
  end

  defp handle_rpc_call("reached_target", %{"run" => simulation_run_id, "agent" => agent_id}, state) do
    DirectDebug.info("SimUdpConnector - handling 'reached_target' method. scenario=#{simulation_run_id}; agent=#{agent_id}")
    Scenario.on_agent_reached_target(simulation_run_id, agent_id)
    {:noreply, state}
  end

  defp handle_rpc_call("agent_destroyed", %{"id" => agent_id}, state) do
    case Registry.lookup(GeneticsEngine.Onta.OntosRegistry, agent_id) do
      [{pid, _}] ->
        Logger.info("Terminating Ontos for agent #{agent_id}")
        GeneticsEngine.Onta.OntosSupervisor.terminate_ontos(pid)
      [] ->
        Logger.warning("No Ontos found for agent #{agent_id}")
    end
    {:noreply, state}
  end

  #  ============================== SENSOR UPDATE HANDLERS ============================

  defp handle_rpc_call("batch", batch, state) do
    DirectDebug.extra("#{state.name} - handling batch: #{inspect(batch)}")

    # Forward batch to WebSocket clients
#    SimulationSocket.broadcast_batch(batch)

    group_by_scenario(batch["sensor_data"])
    |> Enum.each(fn scenario ->
      DirectDebug.extra("#{state.name} - extracted data from batch for scenario '#{inspect(scenario)}'")
      GeneticsEngine.Sim.Scenario.route_sensor_data_batch(scenario["scenario"],scenario["entries"])
    end)

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
