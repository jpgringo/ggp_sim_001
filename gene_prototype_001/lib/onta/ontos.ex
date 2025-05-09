defmodule GenePrototyp0001.Onta.Ontos do
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

    # Create ETS table for sensor data
    # Each entry is {sensor_id, values}
    table_name = sensor_table_name(agent_id)
    :ets.new(table_name, [:named_table, :public, :set])

    {:ok, %{
      agent_id: agent_id,
      available_actuators: available_actuators,
      numen_supervisor: numen_sup,
      numen_pids: numen_pids,
      sensor_table: table_name
    }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_sensor_data, _from, state) do
    data = get_all_sensor_data(state.sensor_table)
    {:reply, data, state}
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
  def process_incoming_sensor_set(sensor_data_set, state) do
    # TODO: if local state updates happen at all, they should happen separately from the processing

    # Notify all Numina
    Enum.each(state.numen_pids, fn pid ->
      GenServer.cast(pid, {:process_sensor_data_set, sensor_data_set})
    end)

#    Logger.debug("Ontos #{state.agent_id} received sensor data: #{inspect([sensor_id, values])}")

    {:noreply, :ok, state}
  end


  # there is an asynchronous version below
  @impl true
  def process_incoming_sensor_datum([sensor_id, values], state) do
    # Store sensor data
    new_state = update_sensor_data(state, sensor_id, values)

    # Get current sensor data and notify all Numina
    data = get_all_sensor_data(new_state.sensor_table)
    Enum.each(new_state.numen_pids, fn pid ->
      GenServer.cast(pid, {:process_sensor_data, data})
    end)

    Logger.debug("Ontos #{state.agent_id} received sensor data: #{inspect([sensor_id, values])}")
    {:noreply, :ok, new_state}
  end



  #  @impl true
#  def handle_cast({:sensor_batch, [sensor_datum]}, state) do
#    Logger.debug("Ontos received sensor batch with a SINGLE datum: #{inspect(sensor_datum)}")
#    {:noreply, state}
#  end

  @impl true
  def handle_cast({:sensor_batch, sensor_data_list}, state) do
    Logger.debug("Ontos received sensor batch: #{inspect(sensor_data_list)}")
    preprocessed_input = preprocess_data_batch(sensor_data_list)
    Logger.debug("PREPROCESSED sensor batch: #{inspect(preprocessed_input)}")

    process_incoming_sensor_set(preprocessed_input, state)

    # [
    #   [0, [-82.0504150390625, 57.1640548706055]],
    #   [0, [55.0231323242188, 83.501220703125]],
    #   [1, [0.0071563720703125, 13.0091857910156, 0.0, -1.0]], [0, [55.0231323242188, 83.501220703125]]]

#    sensor_data_list
#    |> Enum.each(fn sensor_datum ->
#      Logger.debug("\tindividual datum: #{inspect(sensor_datum)}")
#      # use the synchronous version to retain receipt order
#      process_incoming_sensor_datum(sensor_datum, state)
#    end)

    {:noreply, state}
  end

  # there is a synchronous version above
  @impl true
  def handle_cast({:sensor_data, [sensor_id, values]}, state) do
    # Store sensor data
    new_state = update_sensor_data(state, sensor_id, values)

    # Get current sensor data and notify all Numina
    data = get_all_sensor_data(new_state.sensor_table)
    Enum.each(new_state.numen_pids, fn pid ->
      GenServer.cast(pid, {:process_sensor_data, data})
    end)

    Logger.debug("Ontos #{state.agent_id} received sensor data: #{inspect([sensor_id, values])}")
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:numen_commands, commands}, state) do
    # Process commands from Numina
    Enum.each(commands, fn command ->
      case command do
        {:actuator_data, payload} ->
          GenServer.call(:SimUdpConnector, {:send_actuator_data,
            state.agent_id,
            payload}
          )
          Logger.info("Ontos #{state.agent_id} sending actuator data: #{inspect(payload)}")
        _ ->
          Logger.warning("Ontos #{state.agent_id} received unknown command: #{inspect(command)}")
      end
    end)
    {:noreply, state}
  end

  # Helper functions
  defp via_tuple(agent_id) do
    {:via, Registry, {GenePrototyp0001.Onta.OntosRegistry, agent_id}}
  end

  defp update_sensor_data(state, sensor_id, values) do
    # Simply store the latest values for this sensor
    :ets.insert(state.sensor_table, {sensor_id, values})
    state
  end

  defp sensor_table_name(agent_id) do
    # Create a unique atom for this Ontos's sensor table
    String.to_atom("ontos_#{agent_id}_sensors")
  end

  @doc """
  Get current sensor data as a list of {sensor_id, values} tuples.
  """
  def get_sensor_data(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_sensor_data)
  end

  # Get all sensor data from ETS
  defp get_all_sensor_data(table) do
    :ets.tab2list(table)
  end

  def preprocess_data_batch(sensor_data_list) do
    # bin the data by sensor id
    grouped_data = sensor_data_list |> Enum.group_by(fn [id, _] -> id end)
    IO.puts("grouped_data: #{inspect(grouped_data)}")
    # average each sensor; this is just one way to summarize a batch. It may be more relevant
    # to grab the most recent entry for each sensor only (but ultimately for the algorithm to
    # decide? Should this functionality evolve also?)
    vector_set = Enum.map(grouped_data, fn {sensor_id, vals} ->
      # we're effectively discarding the individual sensor_id value from each input,
      # but given the way we grouped the data above, we can trust the map key as the input sensor id
      [sensor_id,
         vals
           # grab just the values from each input
           |> Enum.map(fn [_, vector] -> vector end)
           # 'pivot' the vector collection so all each column is grouped together
           |> Enum.zip_with(& &1)
           # get the average of each  pivoted column
           |> Enum.map(&(Enum.sum(&1) / length(&1)))
      ]
    end)
    vector_set
  end
end
