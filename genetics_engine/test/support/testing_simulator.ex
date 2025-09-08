defmodule GeneticsEngine.Test.TestingSimulator do
  @moduledoc false

  use GenServer
  require DirectDebug

  @testing_simulator_name :TestingSimulator

  #============================================= API ============================================= #

  def announce do
    DirectDebug.info("announcing test simulator")
  end

  def initiate_scenario_run(opts) do
    GenServer.call(@testing_simulator_name, {:initiate_scenario_run, opts})
  end

  def stop_scenario_run(resource_id, run_id) do
    GenServer.call(@testing_simulator_name,
      {:stop_scenario_run,
        %{resource_id: resource_id,
          run_id: run_id
        }})
  end

  def send_sensor_data_batch(run_id, sensor_data_batch) do
    GenServer.call(@testing_simulator_name, {:send_sensor_data_batch, run_id, sensor_data_batch})
  end

  def send_target_reached_event(run_id, agent_id) do
    DirectDebug.error("TestingSimulator.send_target_reached_event")
    GenServer.call(@testing_simulator_name, {:send_target_reached, run_id, agent_id})
  end

  def quit() do
    GenServer.call(@testing_simulator_name, :quit)
  end

  #======================================= IMPLEMENTATION ======================================== #
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @testing_simulator_name)
  end

  @impl true
  def init(init_args) do
    DirectDebug.info("initing Testing Simulator starting with args #{inspect(init_args)}...")

    if Process.whereis(:pg) != nil do
      DirectDebug.info("testing simulator joining pg group :actuator_events")
      :pg.join(:actuator_events, self())
    end

    socket = case :gen_udp.open(init_args.receive_port, [:binary, active: true, reuseaddr: true]) do
      {:ok, socket} ->
        DirectDebug.info("Testing Simulator listening on socket #{inspect(Port.info(socket))}")
        socket
      err ->
        raise "couldn't open socket: #{inspect(err)}"
        nil
    end
    {:ok, %{socket: socket, send_ip: init_args.send_ip, send_port: init_args.send_port}}
  end

  @impl true
  def handle_call({:initiate_scenario_run,
    %{resource_id: scenario_resource_id, run_id: run_id, agents: agents}},
        _from, %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.info("#{@testing_simulator_name} - handling :initiate_scenario_run. res=#{scenario_resource_id}, run=#{run_id}")
    notification = Jason.encode!(
      %{
        jsonrpc: "2.0",
        method: "scenario_started",
        params: %{
          scenario: scenario_resource_id,
          unique_id: run_id,
          agents: agents
        }
      })
    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:stop_scenario_run,
    %{resource_id: scenario_resource_id, run_id: run_id}},
        _from, %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.info("#{@testing_simulator_name} - handling :stop_scenario_run. res=#{scenario_resource_id}, run=#{run_id}")
    notification = Jason.encode!(
      %{
        jsonrpc: "2.0",
        method: "scenario_stopped",
        params: %{
            scenario: scenario_resource_id,
            id: run_id
          }
      })
    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  # deprecated in favour of the batch implementation below
  @impl true
  def handle_call({:send_sensor_data, agent_id, data}, _from, state = %{socket: socket, send_ip: send_ip, send_port: send_port}) do
    DirectDebug.extra("TestingSimulator received send_sensor_data message message: #{inspect(agent_id)}-#{inspect(data)}")

    encoded_pid = self() |> :erlang.term_to_binary() |> Base.encode64()
    notification = Jason.encode!(%{
      jsonrpc: "2.0",
      method: "batch",
      params: %{
        sensor_data: [
          %{scenario: "Y34EW7AR", agent: 38436603325, data: [0,[69.7859802246094,71.6234359741211]]},
          %{scenario: "Y34EW7AR", agent: 38537266626, data: [0,[-92.4292984008789,-38.1683692932129]]}
        ]
      },
      subscribers: [encoded_pid]
    })

    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:send_sensor_data_batch, run_id, data},
        _from,
        %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.extra("TestingSimulator received send_sensor_data_batch message: #{inspect(run_id)}-#{inspect(data)}")

    notification = Jason.encode!(%{
      jsonrpc: "2.0",
      method: "batch",
      params: %{
        sensor_data: Enum.map(data, fn {agent, sensor_data} ->
          %{scenario: run_id, agent: agent, data: sensor_data}
        end)
      },
    })

    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:send_target_reached, run_id, agent_id},
        _from,
        %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.section("TestingSimulator received send_target_reached message: #{inspect(run_id)}-#{inspect(agent_id)}")

    notification = Jason.encode!(%{
      jsonrpc: "2.0",
      method: "reached_target",
      params: %{
        scenario: run_id,
        agent: agent_id
      },
    })

    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:quit,
        _from,
        %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.section("TestingSimulator received quit message")

    notification = Jason.encode!(%{
      jsonrpc: "2.0",
      method: "sim_stopping",
      params: %{},
    })

    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(msg, _from, state) do
    DirectDebug.warning("TestingSimulator received unknown message: #{inspect(msg)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:udp, _socket, _ip, _port, data}, state) do
    DirectDebug.info("TestingSimulator received udp packet: #{inspect(data)}")
    case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params}} ->
      case method do
        "actuator_data" ->
          if Process.whereis(:pg) != nil do
            Enum.each(:pg.get_members(:actuator_events), & send(&1, {:actuator_data, params}))
          end

      end
    end

    {:noreply, state}
  end

    @impl true
  def handle_info(msg, state) do
    DirectDebug.warning("Testing simulator received an unknown message: #{inspect(msg)}; state: #{inspect(state)}")
    {:noreply, state}
  end

end
