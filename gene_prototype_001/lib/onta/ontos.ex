defmodule GenePrototype0001.Onta.Ontos do
  use GenServer
  require Logger
  require DirectDebug

  alias GenePrototype0001.Sim.UdpConnectionServer

  #============================================= API ============================================= #

  def get_state(ontos_pid) when is_pid(ontos_pid) do
    GenServer.call(ontos_pid, :get_state)
  end

  def get_state(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_state)
  end

  def get_event_count(agent_id, event_type) do
    state = GenServer.call(via_tuple(agent_id), :get_state)
    case event_type do
      :actuator -> state.actuators_issued
      _ ->
        :logger.error("Ontos '#{agent_id}' - request for unknown event type #{event_type}")
        0
    end
  end

  def get_numina(ontos_pid) when is_pid(ontos_pid) do
    GenServer.call(ontos_pid, :get_numina)
  end

  def add_numen(agent_id, numen_module) do
    GenServer.call(via_tuple(agent_id), {:add_numen, numen_module})
  end

  def remove_numen(agent_id, numen_pid) do
    GenServer.call(via_tuple(agent_id), {:remove_numen, numen_pid})
  end

  def handle_sensor_data(ontos_pid, data) do
    GenServer.cast(ontos_pid, {:sensor_batch, data})
  end

  def handle_numen_commands(ontos_pid, commands) do
    GenServer.cast(ontos_pid, {:numen_commands, commands})
  end

  #======================================= IMPLEMENTATION ======================================== #

  # Client API
  def start_link({agent_id, opts}) do
    unique_id = "#{opts[:scenario_id]}_#{agent_id}"
#    name = via_tuple(agent_id)
    name = via_tuple(unique_id)
    DirectDebug.info("Ontos.start_link(#{inspect(unique_id)}, #{inspect(opts)}) -> name=#{inspect(name)}")
    GenServer.start_link(__MODULE__, {unique_id, [agent_id: agent_id] ++ opts}, name: name)
  end

  # Server callbacks

  @impl true
  def init({unique_id, opts}) do
    DirectDebug.info("Starting Ontos for agent #{unique_id} with opts: #{inspect(opts)}")
    available_actuators = Keyword.get(opts, :available_actuators, 0)
    numina = Keyword.get(opts, :numina, [])
    agent_id = Keyword.get(opts, :agent_id)

    # Start the NumenSupervisor
    {:ok, numen_sup} = GenePrototype0001.Numina.NumenSupervisor.start_link(unique_id)

    # Start initial Numina
    numen_pids = for numen_module <- numina do
      DirectDebug.info("Starting Numen: #{inspect(numen_module)}")
      {:ok, pid} = GenePrototype0001.Numina.NumenSupervisor.start_numen(numen_sup, numen_module, unique_id)
      pid
    end

    # Create ETS table for sensor data
    # Each entry is {sensor_id, values}
    table_name = sensor_table_name(unique_id)
    :ets.new(table_name, [:named_table, :public, :set])

    {:ok, %{
      agent_id: unique_id,
      raw_id: agent_id,
      available_actuators: available_actuators,
      actuators_issued: 0,
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
    case GenePrototype0001.Numina.NumenSupervisor.start_numen(state.numen_supervisor, numen_module, state.raw_id) do
      {:ok, pid} ->
        # storing the pids in a list, as this is the easiest way of maintaining a determinate order
        # TODO: consider making numina a custom linked list, in which each Numen knows the pid of the next one in the sequence (might be more trouble than its worth)
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
  def handle_call(:get_numina, _from, state) do
    {:reply, {:ok, state.numen_pids}, state}
  end


  defp process_incoming_sensor_set(sensor_data_set, state) do
    # TODO: if local state updates happen at all, they should happen separately from the processing
    # TODO: ACTUALLY… the way this is architected is messed up. Should be a `call`
    DirectDebug.extra("Ontos - processing incoming sensor set. sensor_data_set: #{inspect(sensor_data_set)}")
    # Notify all Numina
    Enum.each(state.numen_pids, fn pid ->
      GenePrototype0001.Numina.Numen.process_sensor_data_set(pid, sensor_data_set)
    end)

    {:noreply, :ok, state}
  end


  @impl true
  def handle_cast({:sensor_batch, sensor_data_list}, state) do
    DirectDebug.info("Ontos #{state.agent_id} received sensor batch: #{inspect(sensor_data_list)}")
    preprocessed_input = preprocess_data_batch(sensor_data_list)
    DirectDebug.extra("#{state.agent_id} - preprocessed sensor batch: #{inspect(preprocessed_input)}")

    process_incoming_sensor_set(preprocessed_input, state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:numen_commands, commands}, state) do
    # Process commands from Numina
    new_actuator_sends = Enum.reduce(commands, 0, fn command, acc ->
      case command do
        {:actuator_data, payload} ->
          DirectDebug.info("Ontos #{state.agent_id} sending actuator data: #{inspect(payload)}")
          UdpConnectionServer.send_actuator_data(state.raw_id, payload)
          acc + 1
        _ ->
          Logger.warning("Ontos #{state.agent_id} received unknown command: #{inspect(command)}")
          acc
      end
    end)
    {:noreply, %{state | actuators_issued: state.actuators_issued + new_actuator_sends}}
  end

  # Helper functions
  defp via_tuple(agent_id) do
    {:via, Registry, {GenePrototype0001.Onta.OntosRegistry, agent_id}}
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

  def isolate_and_average_grouped_data_batch(grouped_data) do
    DirectDebug.extra("isolating and averaging grouped data batch: #{inspect(grouped_data)}")
    Enum.map(grouped_data, fn {sensor_id, vals} ->
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
  end

  def preprocess_data_batch(sensor_data_list) do
    DirectDebug.extra("Ontos processing data batch: #{inspect(sensor_data_list)}")
    # bin the data by sensor id
    grouped_data = sensor_data_list |> Enum.group_by(fn [id, _] -> id end)

    # average each sensor; this is just one way to summarize a batch. It may be more relevant
    # to grab the most recent entry for each sensor only (but ultimately for the algorithm to
    # decide? Should this functionality evolve also?)
    isolate_and_average_grouped_data_batch(grouped_data)
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("Ontos with state #{inspect(state)} terminating for reason '#{inspect(reason)}'")
  end
end
