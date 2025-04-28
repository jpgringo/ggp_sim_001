defmodule GenePrototype0001.Ontos do
  use GenServer
  require Logger
  import Nx.Defn

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
  # Constants for sensor data storage
  @max_sensor_history 1000  # Maximum number of readings to keep per sensor
  @max_sensors 100         # Maximum number of sensors per Ontos
  @default_dtype {:f, 32}  # Default dtype for Nx tensors

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

    # Create ETS table for sensor data
    # Each entry is {sensor_id, write_pos, circular_buffer}
    table_name = sensor_table_name(agent_id)
    :ets.new(table_name, [:named_table, :public, :set])

    {:ok, %{
      agent_id: agent_id,
      available_actuators: available_actuators,
      numen_supervisor: numen_sup,
      numen_pids: numen_pids,
      sensor_table: table_name,
      tensor_cache: nil,       # Cached Nx tensor of sensor data
      tensor_cache_valid: false # Whether the cache is valid
    }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_sensor_tensor, _from, %{tensor_cache_valid: true, tensor_cache: cache} = state) do
    {:reply, cache, state}
  end

  def handle_call(:get_sensor_tensor, _from, state) do
    tensor = build_sensor_tensor(state.sensor_table)
    new_state = %{state | tensor_cache: tensor, tensor_cache_valid: true}
    {:reply, tensor, new_state}
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
    # Store sensor data
    new_state = update_sensor_data(state, sensor_id, values)

    case values do
      # Match both +0.0 and -0.0
      [v1, v2 | _] when v1 in [+0.0, -0.0] and v2 in [+0.0, -0.0] ->
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
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:sensor_data, [sensor_id, values]}, state) when sensor_id == 1 do
    # Store sensor data
    new_state = update_sensor_data(state, sensor_id, values)

    # When touch sensor is triggered, send command to stop movement
    stop_command = [0, [0.0, 0.0]]

    GenePrototype0001.UdpConnectionServer.send_actuator_data(
      state.agent_id,
      stop_command
    )

    Logger.info("Ontos #{state.agent_id} detected collision, sending stop command: #{inspect(stop_command)}")
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:sensor_data, [sensor_id, values]}, state) do
    # Store sensor data even for unhandled sensor types
    new_state = update_sensor_data(state, sensor_id, values)
    Logger.debug("Ontos #{state.agent_id} received unhandled sensor data: #{inspect([sensor_id, values])}")
    {:noreply, new_state}
  end

  # Helper functions
  defp via_tuple(agent_id) do
    {:via, Registry, {GenePrototype0001.OntosRegistry, agent_id}}
  end

  defp update_sensor_data(state, sensor_id, values) when sensor_id < @max_sensors do
    table = state.sensor_table
    case :ets.lookup(table, sensor_id) do
      [] ->
        # First reading for this sensor
        buffer = :array.new(@max_sensor_history, fixed: true)
        buffer = :array.set(0, values, buffer)
        :ets.insert(table, {sensor_id, 1, buffer})
      [{^sensor_id, write_pos, buffer}] ->
        # Update existing sensor data
        new_pos = rem(write_pos, @max_sensor_history)
        new_buffer = :array.set(new_pos, values, buffer)
        :ets.insert(table, {sensor_id, new_pos + 1, new_buffer})
    end
    # Invalidate tensor cache since data changed
    %{state | tensor_cache_valid: false}
  end

  defp sensor_table_name(agent_id) do
    # Create a unique atom for this Ontos's sensor table
    String.to_atom("ontos_#{agent_id}_sensors")
  end

  @doc """
  Get sensor data as an Nx tensor. Shape will be {@max_sensors, max_values_per_sensor}.
  Missing values are filled with 0.0.
  """
  def get_sensor_tensor(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_sensor_tensor)
  end

  # Efficiently builds an Nx tensor from the ETS sensor data
  def build_sensor_tensor(table) do
    # Create a zero-filled tensor
    base = Nx.broadcast(0.0, {@max_sensors, @max_sensor_history}, type: @default_dtype)
    
    # Collect all sensor data and prepare tensors
    sensors = :ets.tab2list(table)
    
    # Update tensor with sensor data
    Enum.reduce(sensors, base, fn {sensor_id, write_pos, buffer}, acc ->
      values = :array.to_list(buffer)
      # Only take up to write_pos values to avoid uninitialized data
      valid_values = Enum.take(values, min(write_pos, @max_sensor_history))
      
      # Convert to tensor outside of defn
      row_tensor = Nx.tensor(valid_values, type: @default_dtype)
      update_sensor_slice(acc, sensor_id, row_tensor)
    end)
  end

  # This is the part that can be JIT compiled since it takes tensors as input
  defnp update_sensor_slice(tensor, sensor_id, row_tensor) do
    Nx.put_slice(tensor, [sensor_id, 0], row_tensor)
  end
end
