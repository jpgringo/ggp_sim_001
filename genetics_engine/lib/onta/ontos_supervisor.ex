defmodule GeneticsEngine.Onta.OntosSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(init_args) do
    :logger.info("Starting Ontos supervisor... init_args: #{inspect(init_args)}")
    # TODO: this 'dance' around registry names is only necessary until the direct creation of
    #       Onta (i.e., not via Scenarios) is eliminated
    name = case init_args do
      [name: name_str] when is_binary(name_str) ->
        {:via, Registry, {GeneticsEngine.Onta.OntosRegistry, name_str}}
      _ -> __MODULE__
    end
    DynamicSupervisor.start_link(__MODULE__, init_args, name: name)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Initializing Ontos supervisor...")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_ontos(agent_id, params \\ %{}) do
    available_actuators = Map.get(params, "actuators", 0)
    numina = Map.get(params, "numina", [GeneticsEngine.Numina.BasicMotionNumen])
    Logger.debug("STARTING ONTOS #{agent_id}. params: #{inspect(params)}")
    spec = {GeneticsEngine.Onta.Ontos, {agent_id, [available_actuators: available_actuators, numina: numina]}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_ontos(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
