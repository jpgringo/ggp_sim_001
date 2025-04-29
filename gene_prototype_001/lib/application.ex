defmodule GenePrototype0001.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Registry for Ontos instances
      {Registry, keys: :unique, name: GenePrototype0001.OntosRegistry},
      # Registry for Numina instances
      {Registry, keys: :unique, name: GenePrototype0001.Registry},
      # Dynamic supervisor for Ontos instances
      {GenePrototype0001.OntosSupervisor, []},
      # External connection supervisor
      {GenePrototype0001.ExternalConnectionSupervisor, [
        receive_port: 7400,
        send_ip: "127.0.0.1",
        send_port: 7401
      ]},
      # Bandit HTTP server
      {Bandit, plug: GenePrototype0001.Bandit.Router, port: Application.get_env(:bandit, :port, 4000)}
    ]

    opts = [strategy: :one_for_one, name: GenePrototype0001.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
