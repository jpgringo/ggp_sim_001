defmodule GenePrototype0001.Numina.NumenSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: via_tuple(init_arg))
  end

  def start_numen(supervisor, numen_module, agent_id) do
    # Get the Ontos pid from the registry
    ontos_pid = case Registry.lookup(GenePrototype0001.OntosRegistry, agent_id) do
      [{pid, _}] -> pid
      _ -> nil
    end

    if ontos_pid do
      DynamicSupervisor.start_child(supervisor, {numen_module, {agent_id, ontos_pid}})
    else
      {:error, :ontos_not_found}
    end
  end

  def terminate_numen(supervisor, pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one
    )
  end

  # Private helpers
  defp via_tuple(agent_id) do
    {:via, Registry, {GenePrototype0001.Registry, {__MODULE__, agent_id}}}
  end
end
