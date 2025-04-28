defmodule GenePrototype0001.Ontos do
  use GenServer
  require Logger

  # Client API
  def start_link({agent_id, opts}) do
    name = via_tuple(agent_id)
    GenServer.start_link(__MODULE__, {agent_id, opts}, name: name)
  end

  def add_numen(agent_id, numen_module) do
    GenServer.call(via_tuple(agent_id), {:add_numen, numen_module})
  end

  def remove_numen(agent_id, numen_pid) do
    GenServer.call(via_tuple(agent_id), {:remove_numen, numen_pid})
  end

  def get_state(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_state)
  end

  def handle_sensor_data(agent_id, data) do
    GenServer.cast(via_tuple(agent_id), {:sensor_data, data})
  end

  # Server callbacks
  @impl true
  def init({agent_id, opts}) do
    Logger.info("Starting Ontos for agent #{agent_id} with opts: #{inspect(opts)}")
    available_actuators = Keyword.get(opts, :available_actuators, 0)
    numina = Keyword.get(opts, :numina, [])

    # Start the NumenSupervisor
    {:ok, numen_sup} = GenePrototype0001.Numina.NumenSupervisor.start_link(agent_id)

    # Start initial Numina
    numen_pids = for numen_module <- numina do
      Logger.info("Starting Numen: #{inspect(numen_module)}")
      {:ok, pid} = GenePrototype0001.Numina.NumenSupervisor.start_numen(numen_sup, numen_module, agent_id)
      pid
    end

    {:ok, %{
      agent_id: agent_id,
      available_actuators: available_actuators,
      numen_supervisor: numen_sup,
      numen_pids: numen_pids
    }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_numen, numen_module}, _from, state) do
    case GenePrototype0001.Numina.NumenSupervisor.start_numen(state.numen_supervisor, numen_module, state.agent_id) do
      {:ok, pid} ->
        new_state = Map.update!(state, :numen_pids, &[pid | &1])
        {:reply, {:ok, pid}, new_state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:remove_numen, numen_pid}, _from, state) do
    case GenePrototype0001.Numina.NumenSupervisor.terminate_numen(state.numen_supervisor, numen_pid) do
      :ok ->
        new_state = Map.update!(state, :numen_pids, &List.delete(&1, numen_pid))
        {:reply, :ok, new_state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_cast({:sensor_data, [sensor_id, values]}, state) when sensor_id == 0 and length(values) >= 2 do
    case values do
      [0.0, 0.0 | _] ->
        # Generate two random numbers between -1.0 and 1.0
        random_values = [:rand.uniform() * 2 - 1, :rand.uniform() * 2 - 1]
        payload = [0, random_values]

        GenePrototype0001.UdpConnectionServer.send_actuator_data(
          state.agent_id,
          payload
        )

        Logger.info("Ontos #{state.agent_id} sending actuator data: #{inspect(payload)}")

      _ ->
        Logger.debug("Ontos #{state.agent_id} received non-zero velocity: #{inspect(values)}")
    end
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sensor_data, [sensor_id, values]}, state) when sensor_id == 1 do
    # When touch sensor is triggered, send command to stop movement
    stop_command = [0, [0.0, 0.0]]

    GenePrototype0001.UdpConnectionServer.send_actuator_data(
      state.agent_id,
      stop_command
    )

    Logger.info("Ontos #{state.agent_id} detected collision, sending stop command: #{inspect(stop_command)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sensor_data, data}, state) do
    Logger.debug("Ontos #{state.agent_id} received unhandled sensor data: #{inspect(data)}")
    {:noreply, state}
  end

  # Helper functions
  defp via_tuple(agent_id) do
    {:via, Registry, {GenePrototype0001.OntosRegistry, agent_id}}
  end
end
