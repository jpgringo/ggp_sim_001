defmodule GenePrototype0001.Sim.ExternalConnectionSupervisor do
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting external connection supervisor...")
    receive_port = Keyword.get(opts, :receive_port, 7400)
    children = [
      {GenePrototype0001.Sim.UdpConnectionServer, receive_port: receive_port},
      {GenePrototype0001.Sim.SimController, []}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
