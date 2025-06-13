defmodule GenePrototype0001.Numina.BasicMotionNumen do
  @moduledoc """
  A specialized Numen that handles basic motion control for an Ontos.
  Processes sensor data to determine appropriate motion commands.
  """

  use GenePrototype0001.Numina.Numen

  def start_link({agent_id, ontos_pid}) do
    GenServer.start_link(__MODULE__, {agent_id, ontos_pid})
  end

  @impl true
  def init({agent_id, ontos_pid}) do
    {:ok, %{agent_id: agent_id, ontos_pid: ontos_pid}}
  end

  @impl true
  def handle_custom(msg, state) do
    Logger.debug("BasicMotionNumen received unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def sensor_data_updated(sensor_data, state) do
    # Get current values for each sensor
    velocity_sensor = get_sensor_values(sensor_data, 0)
    touch_sensor = get_sensor_values(sensor_data, 1)

    Logger.debug("BasicMotionNumen #{state.agent_id} velocity sensor values: #{inspect(velocity_sensor)}; touch sensor values: #{inspect(touch_sensor)}")

    process_sensor_data(velocity_sensor, touch_sensor, state)
    # First check touch sensor - if any non-zero values, stop immediately
    case touch_sensor do
      {:ok, values} ->
        Logger.debug("BasicMotionNumen #{state.agent_id} touch sensor values: #{inspect(values)}")
        if Enum.any?(values, fn v -> abs(v) > 0.001 end) do
          Logger.info("BasicMotionNumen #{state.agent_id} detected collision, stopping")
          {:ok, state, [{:actuator_data, [0, [0.0, 0.0]]}]}
        else
          handle_velocity(velocity_sensor, state)
        end
      :not_found ->
        # No touch sensor data, proceed with velocity handling
        handle_velocity(velocity_sensor, state)
    end
  end

  @impl true
  def sensor_data_updated_new(sensor_data, state) do
    DirectDebug.extra("Numen for #{inspect(state.agent_id)} - sensor_data_updated_new. sensor data: #{inspect(sensor_data)}")
    velocity_sensor = get_sensor_values_new(sensor_data, 0)
    touch_sensor = get_sensor_values_new(sensor_data, 1)

    DirectDebug.extra("BasicMotionNumen #{state.agent_id} velocity sensor values: #{inspect(velocity_sensor)}; touch sensor values: #{inspect(touch_sensor)}")

    # First check touch sensor - if any non-zero values, stop immediately
    case touch_sensor do
      {:ok, values} ->
        DirectDebug.extra("BasicMotionNumen #{state.agent_id} touch sensor values: #{inspect(values)}")
        if Enum.any?(values, fn v -> abs(v) > 0.001 end) do
          Logger.info("BasicMotionNumen #{state.agent_id} detected collision, stopping")
          {:ok, state, [{:actuator_data, [0, [0.0, 0.0]]}]}
        else
          xy_values = normalize_velocity_vector(velocity_sensor)
          DirectDebug.extra("xy_values: #{inspect(xy_values)}")
          handle_velocity(velocity_sensor, state)
        end
      :not_found ->
        DirectDebug.extra("BasicMotionNumen #{state.agent_id} touch sensor data not found. Velocity sensor: #{inspect(velocity_sensor)}")
        # No touch sensor data, proceed with velocity handling
        xy_values = normalize_velocity_vector(velocity_sensor)
        DirectDebug.extra("xy_values: #{inspect(xy_values)}")
        handle_velocity(xy_values, state)
    end
  end

  defp normalize_velocity_vector({:ok, velocity_sensor_data}) do
    case velocity_sensor_data do
      [a, b | _] -> [a, b]
      [a] -> [a, 0]
      [] -> [0, 0]
    end
  end

  defp process_sensor_data(velocity_sensor, _touch_sensor, state) when velocity_sensor == {:ok, [0.0, 0.0]} do
    handle_velocity(velocity_sensor, state)
  end

  defp process_sensor_data(velocity_sensor, :not_found, state) do
    handle_velocity(velocity_sensor, state)
  end


  defp process_sensor_data(velocity_sensor, touch_sensor, state) do
    case touch_sensor do
      {:ok, values} ->
        DirectDebug.extra("BasicMotionNumen #{state.agent_id} touch sensor values: #{inspect(values)}")
        if Enum.any?(values, fn v -> abs(v) > 0.001 end) do
          DirectDebug.extra("BasicMotionNumen #{state.agent_id} detected collision, stopping")
          # clear collision date
          Logger.debug("state: #{inspect(state)}")
          {:ok, state, [{:actuator_data, [0, [0.0, 0.0]]}]}
        else
          xy_values = normalize_velocity_vector(velocity_sensor)
          DirectDebug.extra("xy_values: #{inspect(xy_values)}")
          handle_velocity(xy_values, state)
        end
      :not_found ->
        # No touch sensor data, proceed with velocity handling
        handle_velocity(velocity_sensor, state)
    end
  end

  # Helper to safely get sensor values from the list of tuples
  defp get_sensor_values(sensor_data, target_sensor_id) do
    case Enum.find(sensor_data, fn {id, _} -> id == target_sensor_id end) do
      {_id, values} -> {:ok, values}
      nil -> :not_found
    end
  end

  defp get_sensor_values_new(sensor_data, target_sensor_id) do
    case Enum.find(sensor_data, fn [id, _values] -> id == target_sensor_id end) do
      [_, values] -> {:ok, values}
      nil -> :not_found
    end
  end

  # Handle velocity sensor data
  defp handle_velocity([v1, v2], state) when abs(v1) < 0.001 and abs(v2) < 0.001 do
    # Generate random motion when stationary
    random_values = [:rand.uniform() * 2 - 1, :rand.uniform() * 2 - 1]
    DirectDebug.info("BasicMotionNumen #{state.agent_id} generating random motion: #{inspect(random_values)}")
    {:ok, state, [{:actuator_data, [0, random_values]}]}
  end

  defp handle_velocity(values, state) do
    # Non-zero velocity, let it continue
    DirectDebug.info("BasicMotionNumen #{state.agent_id} moving with velocity: #{inspect(values)}")
    {:ok, state, []}
  end

  defp handle_velocity(:not_found, state) do
    # No velocity data yet
    DirectDebug.info("BasicMotionNumen #{state.agent_id} - velocity data not found}")
    {:ok, state, []}
  end
end
