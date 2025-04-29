defmodule GenePrototype0001.Bandit.Router do
  use Plug.Router

  plug :match
  plug Plug.Logger
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
