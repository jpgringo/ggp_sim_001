defmodule GeneticsEngine.Application do
  use Application

  @impl true
  def start(_type, _args) do
    DirectDebug.info("starting application...")
    children = [
      # Registry for Scenario instances
      {Registry, keys: :unique, name: GeneticsEngine.Sim.ScenarioRegistry},
      # Registry for Ontos instances
      {Registry, keys: :unique, name: GeneticsEngine.Onta.OntosRegistry},
      # Registry for Numina instances
      {Registry, keys: :unique, name: GeneticsEngine.Registry},
      # Registry for WebSocket connections
      {Registry, keys: :duplicate, name: SimulationSocketRegistry},
      # Dynamic supervisor for Scenario instances
      {GeneticsEngine.Sim.ScenarioSupervisor, []},
      # Dynamic supervisor for Ontos instances
      {GeneticsEngine.Onta.OntosSupervisor, []},
      # Scenario Run Report Server
      {GeneticsEngine.Reports.ScenarioRunReportServer, []},
      # External connection supervisor
      {GeneticsEngine.Sim.ExternalConnectionSupervisor, [
        receive_port: Application.get_env(:genetics_engine, :receive_port, 7400),
        send_ip: Application.get_env(:genetics_engine, :send_ip, "127.0.0.1"),
        send_port: Application.get_env(:genetics_engine, :send_port, 7401)
      ]},
      # Bandit HTTP server
      {Bandit,
        plug: GeneticsEngine.Bandit.Router,
        port: Application.get_env(:bandit, :port, 4000),
        thousand_island_options: [
          num_acceptors: 2,
          num_connections: 5,
          read_timeout: 2_000
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: GeneticsEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
