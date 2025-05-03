defmodule GenePrototype0001.Bandit.SelectiveLogger do
  @behaviour Plug

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/api/status"} = conn, _opts), do: conn

  def call(conn, opts) do
    logger_opts = Plug.Logger.init(Keyword.put_new(opts, :log, :info))
    Plug.Logger.call(conn, logger_opts)
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
    response = case sim_ready do
      true ->
        {:ok, sim_state} = GenServer.call(:SimController, :current_sim_state)
        Jason.encode!(%{
          "server" => true,
          "sim" => %{"ready" => true,
          "scenarios" => sim_state.scenarios }
        })
      false ->
        Jason.encode!(%{
          "server" => true,
          "sim" => %{"ready" => false,
          "scenarios" => [] }
        })
    end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
  end

  post "/api/simulation" do
    {:ok, body, conn} = read_body(conn)
    {:ok, params} = Jason.decode(body)
    GenePrototype0001.Sim.SimController.start_sim(params["agents"])
    send_resp(conn, 200, "OK")
  end

  patch "/api/simulation/stop" do
    # {:ok, body, conn} = read_body(conn)
    # {:ok, params} = Jason.decode(body)
     GenePrototype0001.Sim.SimController.stop_sim
    send_resp(conn, 200, "OK")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
