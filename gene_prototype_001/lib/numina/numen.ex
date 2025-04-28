defmodule GenePrototype0001.Numina.Numen do
  @moduledoc """
  Intermediate behaviour that extends GenServer.
  """

  @callback handle_custom(msg :: term(), state :: term()) ::
              {:noreply, new_state :: term()} | {:stop, reason :: term(), new_state :: term()}

  use GenServer

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @behaviour GenePrototype0001.Numina.Numen

      # Default GenServer callbacks that delegate to handle_custom
      @impl true
      def handle_info(msg, state) do
        handle_custom(msg, state)
      end
    end
  end
end
