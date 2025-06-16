defmodule TestingSimulator do
  @moduledoc false

  use GenServer
  require DirectDebug

  @testing_simulator_name :TestingSimulator

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @testing_simulator_name)
  end

  @impl true
  def init(init_args) do
    DirectDebug.info("initing Testing Simulator starting with args #{inspect(init_args)}...")
    socket = case :gen_udp.open(init_args.receive_port, [:binary, active: true, reuseaddr: true]) do
      {:ok, socket} ->
        DirectDebug.info("Testing Simulator listening on socket #{inspect(Port.info(socket))}")
        socket
      err ->
        raise "couldn't open socket: #{inspect(err)}"
        nil
    end
    {:ok, %{socket: socket, send_ip: init_args.send_ip, send_port: init_args.send_port, subscribers: []}}
  end

  @impl true
  def handle_call({:initiate_scenario_run,
    %{resource_id: scenario_resource_id, run_id: run_id, agents: agents} = params},
        _from, %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.info("#{@testing_simulator_name} - handling :initiate_scenario_run. res=#{scenario_resource_id}, run=#{run_id}")
    additional_data = case Map.get(params, :subscribers) do
      nil -> %{}
      subscribers -> %{subscribers: subscribers}
    end
    DirectDebug.extra(">>>> params: #{inspect(params)} -> #{inspect(additional_data)}")
    notification = Jason.encode!(
      %{
        jsonrpc: "2.0",
        method: "scenario_started",
        params: Map.merge(%{
          scenario: scenario_resource_id,
          unique_id: run_id,
          agents: agents
        },
        additional_data)
      })
    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:stop_scenario_run,
    %{resource_id: scenario_resource_id, run_id: run_id, subscribers: subscribers}},
        _from, %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.info("#{@testing_simulator_name} - handling :stop_scenario_run. res=#{scenario_resource_id}, run=#{run_id}; subscribers: #{inspect(subscribers)}")
    notification = Jason.encode!(
      %{
        jsonrpc: "2.0",
        method: "scenario_stopped",
        params: Map.merge(%{
            scenario: scenario_resource_id,
            id: run_id
          },
          %{subscribers: subscribers})
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
  def handle_call({:send_sensor_data_batch, run_id, data}, from, state) do
    DirectDebug.extra("TestingSimulator received send_sensor_data_batch message WITH NO SUBSCRIBERS!!: #{inspect(run_id)}-#{inspect(data)}")
    handle_call({:send_sensor_data_batch, run_id, data, []}, from, state)
  end

  @impl true
  def handle_call(
        {:send_sensor_data_batch, run_id, data, subscribers},
        _from,
        %{socket: socket, send_ip: send_ip, send_port: send_port} = state) do
    DirectDebug.extra("TestingSimulator received send_sensor_data_batch message: #{inspect(run_id)}-#{inspect(data)}; subscribers: #{inspect(subscribers)}")

    encoded_pid = self() |> :erlang.term_to_binary() |> Base.encode64()
    notification = Jason.encode!(%{
      jsonrpc: "2.0",
      method: "batch",
      params: %{
        sensor_data: Enum.map(data, fn {agent, sensor_data} ->
          %{scenario: run_id, agent: agent, data: sensor_data}
        end),
        subscribers: [encoded_pid | subscribers]
      },
    })

    :gen_udp.send(socket, to_charlist(send_ip), send_port, notification)
    updated_subscribers = subscribers ++ state.subscribers
    {:reply, :ok, Map.merge(state, %{subscribers: updated_subscribers})}
  end

  @impl true
  def handle_call(msg, _from, state) do
    DirectDebug.warning("TestingSimulator received unknown message: #{inspect(msg)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:udp, _socket, _ip, _port, data}, state) do
    DirectDebug.info("TestingSimulator received udp packet: #{inspect(data)}")
    [first_subscriber | remaining_subscribers] = state.subscribers
    case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params}} ->
      case method do
        "actuator_data" ->
          send(Base.decode64!(first_subscriber) |> :erlang.binary_to_term, {:actuator_data, params})

      end
    end

    {:noreply, Map.merge(state, %{subscribers: remaining_subscribers})}
  end

    @impl true
  def handle_info(msg, state) do
    DirectDebug.warning("Testing simulator received an unknown message: #{inspect(msg)}; state: #{inspect(state)}")
    {:noreply, state}
  end

end
