defmodule GenePrototype0001.Numina.NumenSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: via_tuple(init_arg))
  end

  def start_numen(supervisor, numen_module, init_arg) do
    spec = %{
      id: numen_module,
      start: {numen_module, :start_link, [init_arg]},
      restart: :permanent,
      type: :worker
    }

    DynamicSupervisor.start_child(supervisor, spec)
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
