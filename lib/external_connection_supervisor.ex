defmodule GenePrototype0001.ExternalConnectionSupervisor do
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting external connection supervisor...")
    udp_port = Keyword.get(opts, :udp_port, 7400)
    children = [
      {GenePrototype0001.UdpConnectionServer, port: udp_port}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
