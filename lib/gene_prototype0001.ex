defmodule GenePrototype0001 do
  @moduledoc """
  GenePrototype0001: Root application module.
  """

  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Starting application...")
    receive_port = Application.get_env(:gene_prototype_0001, :receive_port, 7400)
    send_ip = Application.get_env(:gene_prototype_0001, :send_ip, "127.0.0.1")
    send_port = Application.get_env(:gene_prototype_0001, :send_port, 7401) 
    children = [
      {GenePrototype0001.ExternalConnectionSupervisor, receive_port: receive_port, send_ip: send_ip, send_port: send_port}
    ]
    opts = [strategy: :one_for_one, name: GenePrototype0001.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Hello world.

  ## Examples

      iex> GenePrototype0001.hello()
      :world

  """
  def hello do
    :world
  end
end
