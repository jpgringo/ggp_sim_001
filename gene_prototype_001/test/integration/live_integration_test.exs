defmodule GenePrototype0001.Bandit.LiveIntegrationTest do
  use ExUnit.Case

  setup_all do
    port = 4003
    start_supervised!({Bandit, plug: GenePrototype0001.Bandit.Router, scheme: :http, port: port})
    {:ok, base_url: "http://localhost:#{port}"}
  end

  setup do
    :ok
  end

  test "POST /api/scenario works end-to-end", %{base_url: url} do
    body = ~s({"scenario": "test"})
    headers = [{"content-type", "application/json"}]

    {:ok, resp} = Req.post(url <> "/api/scenario", body: body, headers: headers)

    assert resp.status == 200
    assert resp.body =~ "OK"
  end

  test "receive scenario_started via UDP", _ do
    {:ok, ip} = :inet.parse_address(~c"127.0.0.1")
    scenario_name = nil
    scenario_friendly_name = case scenario_name do
      nil -> "null"
      _ -> "\"#{scenario_name}\""
    end
    scenario_id = "EY9KWWY3"
    scenario_registry_name = case scenario_name do
      nil -> "unnamed_#{scenario_id}"
      _ -> "#{scenario_name}_#{scenario_id}"
    end

    send(:SimUdpConnector, {:udp, nil, ip, 7400,  "{\"jsonrpc\":\"2.0\",\"method\":\"scenario_started\",\"params\":{\"agents\":[{\"actuators\":1,\"id\":\"41976595892\"}],\"scenario\":#{scenario_friendly_name},\"unique_id\":\"#{scenario_id}\"}}" })

    wait_until(fn ->
      DynamicSupervisor.which_children(GenePrototype0001.Sim.ScenarioSupervisor)
      |> length()
      |> Kernel.==(1)
    end)

    [{_, active_scenario_pid, _, _} |  _] = DynamicSupervisor.which_children(GenePrototype0001.Sim.ScenarioSupervisor)
    {:ok, name} = GenServer.call(active_scenario_pid, :get_name)
    assert name == scenario_registry_name
  end


  # ============================  SUPPORTING FUNCTIONS ============================ #

  def wait_until(fun, timeout \\ 500, interval \\ 10) do
    start = System.monotonic_time(:millisecond)
    do_wait_until(fun, start, timeout, interval)
  end

  defp do_wait_until(fun, start, timeout, interval) do
    now = System.monotonic_time(:millisecond)
    if now - start > timeout do
      raise "Condition not met within #{timeout}ms"
    end

    IO.puts("Checking condition...")
    case fun.() do
      true ->
        IO.puts("Condition met!")
        true
      false ->
        IO.puts("Condition not met, sleeping #{interval}ms")
        Process.sleep(interval)
        do_wait_until(fun, start, timeout, interval)
    end
  end

end
