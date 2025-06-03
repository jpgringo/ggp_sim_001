defmodule GenePrototype0001.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Registry for Scenario instances
      {Registry, keys: :unique, name: GenePrototype0001.Sim.ScenarioRegistry},
      # Registry for Ontos instances
      {Registry, keys: :unique, name: GenePrototype0001.Onta.OntosRegistry},
      # Registry for Numina instances
      {Registry, keys: :unique, name: GenePrototype0001.Registry},
      # Registry for WebSocket connections
      {Registry, keys: :duplicate, name: SimulationSocketRegistry},
      # Dynamic supervisor for Scenario instances
      {GenePrototype0001.Sim.ScenarioSupervisor, []},
      # Dynamic supervisor for Ontos instances
      {GenePrototype0001.Onta.OntosSupervisor, []},
      # External connection supervisor
      {GenePrototype0001.Sim.ExternalConnectionSupervisor, [
        receive_port: 7400,
        send_ip: "127.0.0.1",
        send_port: 7401
      ]},
      # Bandit HTTP server
      {Bandit,
        plug: GenePrototype0001.Bandit.Router,
        port: Application.get_env(:bandit, :port, 4000),
        thousand_island_options: [
          num_acceptors: 2,
          num_connections: 5,
          read_timeout: 2_000
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: GenePrototype0001.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
