defmodule GeneticsEngine.Test.Integration.Servers do
  use ExUnit.Case, async: false
  #  import ExUnit.CaptureLog
  #  import ExUnit.CaptureIO
  require DirectDebug

  #  alias GenePrototype0001.Test.TestSupport
  alias GeneticsEngine.Test.TestingSimulator
  #  alias GenePrototype0001.Test.MessageConfirmation

  @moduletag :external
  @moduletag :integration

  setup_all do
    opts =  %{
      send_ip: "127.0.0.1",
      # note the send/receive reversal; this is mimicking an external client
      send_port: Application.get_env(:gene_server, :receive_port, 7400),
      receive_port: Application.get_env(:gene_server, :send_port, 7401)
    }

    :pg.start_link()
    test_sim_pid = start_supervised!({TestingSimulator, opts})
    TestingSimulator.announce

    {:ok, %{test_sim: test_sim_pid}}
  end

  setup do
    :ok
  end

  describe "HTTP control API:" do
    @tag :http_control
    test "Control API is available" do
      DirectDebug.section("starting 'Control API is available'...")
      {:ok, response} = :httpc.request(:get, {"http://localhost:4000/api/status", []}, [], [])
      {{_, status_code, _}, _headers, _body} = response
      assert status_code == 200, "status code should be 200; got #{inspect(status_code)}"
    end

    test "Gene server is available" do
      DirectDebug.section("starting 'Gene server is available'...")
      {:ok, response} = :httpc.request(:get, {"http://localhost:4000/api/status", []}, [], [])
      {{_, status_code, _}, _headers, body} = response
      assert status_code == 200, "status code should be 200; got #{inspect(status_code)}"
      payload = Jason.decode!(body)
      IO.puts("parsed payload: #{inspect(payload, pretty: true)}")
      assert payload["server"]
    end

    test "Simulation environment is available" do
      DirectDebug.section("starting 'Simulation environment is available'...")
      {:ok, response} = :httpc.request(:get, {"http://localhost:4000/api/status", []}, [], [])
      {{_, status_code, _}, _headers, body} = response
      assert status_code == 200, "status code should be 200; got #{inspect(status_code)}"
      payload = Jason.decode!(body)
      IO.puts("parsed payload: #{inspect(payload, pretty: true)} -> #{inspect(payload["sim"])}")
      assert payload["sim"]["ready"] == true
    end
  end
end
