defmodule GenePrototype0001 do
  @moduledoc """
  GenePrototype0001: Root application module.
  """

  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Starting application...")
    udp_port = Application.get_env(:gene_prototype_0001, :udp_port, 7400)
    children = [
      {GenePrototype0001.ExternalConnectionSupervisor, udp_port: udp_port}
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
