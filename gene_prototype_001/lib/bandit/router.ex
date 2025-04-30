defmodule GenePrototype0001.Bandit.SelectiveLogger do
  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.request_path == "/api/status" do
      conn
    else
      Plug.Logger.call(conn, [])
    end
  end
end

defmodule GenePrototype0001.Bandit.Router do
  use Plug.Router

  # Don't log /api/status requests to avoid log flooding from polling
  plug GenePrototype0001.Bandit.SelectiveLogger

  plug :match
  plug :dispatch

  get "/api/status" do
    sim_ready = GenePrototype0001.Sim.UdpConnectionServer.sim_ready?()
    response = Jason.encode!(%{
      "server" => true,
      "sim" => sim_ready
    })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
