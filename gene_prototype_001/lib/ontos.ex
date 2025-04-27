defmodule GenePrototype0001.Ontos do
  use GenServer
  require Logger

  # Client API
  def start_link(agent_id) do
    name = via_tuple(agent_id)
    GenServer.start_link(__MODULE__, agent_id, name: name)
  end

  def get_state(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_state)
  end

  # Server callbacks
  @impl true
  def init(agent_id) do
    Logger.info("Starting Ontos for agent #{agent_id}")
    {:ok, %{agent_id: agent_id}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Helper functions
  defp via_tuple(agent_id) do
    {:via, Registry, {GenePrototype0001.OntosRegistry, agent_id}}
  end
end
