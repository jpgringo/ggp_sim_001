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
    sim_ready = GenServer.call(:SimUdpConnector, :sim_ready?)
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
    case GenServer.call(:SimController, {:start_sim, params}) do
      :ok ->
        conn
        |> put_resp_header("x-simulation-ws", "/ws/simulation")
        |> send_resp(200, "OK")
      {:error, :simulation_in_progress} -> send_resp(conn, 409, "Simulation in progress")
      resp -> send_resp(conn, 500, Jason.stringify(resp))
    end
  end

  get "/ws/simulation" do
    case conn.method do
      "GET" ->
        conn
        |> WebSockAdapter.upgrade(GenePrototype0001.SimulationSocket, [], timeout: 60_000)
        |> halt()
      _ ->
        send_resp(conn, 400, "Bad Request")
    end
  end

  patch "/api/simulation/stop" do
    GenServer.call(:SimController, :stop_sim)
    send_resp(conn, 200, "OK")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
