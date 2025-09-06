defmodule GeneticsEngine do
  @moduledoc """
  GeneticsEngine: Root application module.
  """

  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Starting application...")
    receive_port = Application.get_env(:genetics_engine, :receive_port, 7400)
    send_ip = Application.get_env(:genetics_engine, :send_ip, "127.0.0.1")
    send_port = Application.get_env(:genetics_engine, :send_port, 7401)
    children = [
      {GeneticsEngine.Sim.ExternalConnectionSupervisor, receive_port: receive_port, send_ip: send_ip, send_port: send_port}
    ]
    opts = [strategy: :one_for_one, name: GeneticsEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Hello world.

  ## Examples

      iex> GeneticsEngine.hello()
      :world

  """
  def hello do
    :world
  end
end
