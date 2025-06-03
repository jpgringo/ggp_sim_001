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

  post "/api/scenario" do
    {:ok, body, conn} = read_body(conn)
    {:ok, params} = Jason.decode(body)
    case GenServer.call(:SimController, {:start_scenario, params}) do
      :ok ->
        conn
        |> put_resp_header("x-scenario-ws", "/ws/scenario")
        |> send_resp(200, "OK")
      {:error, :scenario_in_progress} -> send_resp(conn, 409, "Scenario in progress")
      resp -> send_resp(conn, 500, Jason.encode!(resp))
    end
  end

  get "/ws/scenario" do
    case conn.method do
      "GET" ->
        conn
        |> WebSockAdapter.upgrade(GenePrototype0001.SimulationSocket, [], timeout: 60_000)
        |> halt()
      _ ->
        send_resp(conn, 400, "Bad Request")
    end
  end

  patch "/api/scenario/:scenario_id/stop" do
    DirectDebug.info("handling stop scenario request for #{conn.params["scenario_id"]}")
    _result = GenServer.call(:SimController, {:stop_scenario, conn.params["scenario_id"]})
    send_resp(conn, 200, "OK")
  end

  put "/api/scenario/panic" do
    resp = GenServer.call(:SimController, :panic)
    DirectDebug.info("panic: #{inspect(resp)}")
    send_resp(conn, 200, "OK")
  end

  post "/api/observer" do
    case Process.whereis(:observer) do
      nil ->
        :observer.start()
        send_resp(conn, 200, "OK")
      _pid ->
        send_resp(conn, 409, "Observer is already running")
    end
  end

  delete "/api/observer" do
    case Process.whereis(:observer) do
      nil ->
        send_resp(conn, 404, "Observer is not running")
      _pid ->
        :observer.stop()
        send_resp(conn, 200, "OK")
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
