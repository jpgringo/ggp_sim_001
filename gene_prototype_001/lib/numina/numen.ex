defmodule GenePrototype0001.Numina.Numen do
  @moduledoc """
  Intermediate behaviour that extends GenServer.
  Defines the interface for Numina (plural of Numen) which process sensor data
  and influence Ontos behavior.
  """

  @doc """
  Called when new sensor data is available. Receives the current sensor data as an Nx tensor
  and the current state. The tensor has shape {max_sensors, max_sensor_history}.
  Returns an updated state and optional commands to send to the Ontos.
  """
  @callback sensor_data_updated(sensor_data :: Nx.Tensor.t(), state :: term()) ::
              {:ok, new_state :: term()} |
              {:ok, new_state :: term(), commands :: list()}

  @callback sensor_data_updated_new(sensor_data :: Nx.Tensor.t(), state :: term()) ::
              {:ok, new_state :: term()} |
              {:ok, new_state :: term(), commands :: list()}

  @callback handle_custom(msg :: term(), state :: term()) ::
              {:noreply, new_state :: term()} | {:stop, reason :: term(), new_state :: term()}

  defmacro __using__(_opts) do
    quote do
      use GenServer
      require Logger

      @behaviour GenePrototype0001.Numina.Numen

      # Default GenServer callbacks that delegate to handle_custom
      @impl true
      def handle_info(msg, state) do
        handle_custom(msg, state)
      end

      # Default callback for processing sensor data
      @impl true
      def handle_cast({:process_sensor_data, sensor_data}, state) do
        case sensor_data_updated(sensor_data, state) do
          {:ok, new_state, []} ->
            {:noreply, new_state}
          {:ok, new_state, commands} when is_list(commands) ->
            # Send commands back to the Ontos
            send(state.ontos_pid, {:numen_commands, commands})
            {:noreply, new_state}
        end
      end

      # Default callback for processing sensor data sets
      @impl true
      def handle_cast({:process_sensor_data_set, sensor_data}, state) do
        IO.puts("------------ SENSOR DATA SET PROCESSING NOT IMPLEMENTED! ----------------")
        case sensor_data_updated_new(sensor_data, state) do
          {:ok, new_state, []} ->
            {:noreply, new_state}
          {:ok, new_state, commands} when is_list(commands) ->
            # Send commands back to the Ontos
            send(state.ontos_pid, {:numen_commands, commands})
            {:noreply, new_state}
        end
        {:noreply, state}
      end
    end
  end
end
