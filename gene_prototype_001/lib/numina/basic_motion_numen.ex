defmodule GenePrototype0001.Numina.BasicMotionNumen do
  @moduledoc """
  A specialized Numen that handles basic motion control for an Ontos.
  """

  use GenePrototype0001.Numina.Numen

  def start_link(agent_id) do
    GenServer.start_link(__MODULE__, agent_id)
  end

  @impl true
  def init(agent_id) do
    {:ok, %{agent_id: agent_id}}
  end

  @impl true
  def handle_custom(msg, state) do
    IO.inspect({:received, msg})
    {:noreply, state}
  end
end
