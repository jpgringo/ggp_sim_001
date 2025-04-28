defmodule GenePrototype0001.Ontos do
  use GenServer
  require Logger

  # Client API
  def start_link({agent_id, opts}) do
    name = via_tuple(agent_id)
    GenServer.start_link(__MODULE__, {agent_id, opts}, name: name)
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
    Logger.info("Starting Ontos for agent #{agent_id}")
    available_actuators = Keyword.get(opts, :available_actuators, 0)
    {:ok, %{agent_id: agent_id, available_actuators: available_actuators}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
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
  def handle_cast({:sensor_data, data}, state) do
    Logger.debug("Ontos #{state.agent_id} received unhandled sensor data: #{inspect(data)}")
    {:noreply, state}
  end

  # Helper functions
  defp via_tuple(agent_id) do
    {:via, Registry, {GenePrototype0001.OntosRegistry, agent_id}}
  end
end
