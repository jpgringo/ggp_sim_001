defmodule GenePrototype0001.Bandit.Router do
  use Plug.Router

  plug :match
  plug Plug.Logger
  plug :dispatch

  get "/status" do
    send_resp(conn, 200, "OK")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
