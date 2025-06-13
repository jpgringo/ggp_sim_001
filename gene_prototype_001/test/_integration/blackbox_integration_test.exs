defmodule GenePrototype0001.Test.BlackboxIntegration do
  use ExUnit.Case, async: false
#  import ExUnit.CaptureLog
#  import ExUnit.CaptureIO
  require DirectDebug

#  alias GenePrototype0001.Test.TestSupport

  @moduletag :external

  @alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  setup_all do
    opts =  %{
      send_ip: "127.0.0.1",
      send_port: 7400,
      receive_port: 7401
    }


    test_sim_pid = start_supervised!({TestingSimulator, opts})
    IO.puts("\n\n============\ntest_sim_pid#{inspect(test_sim_pid)}\n==============\n")
    {:ok, %{test_sim: test_sim_pid}}
  end

  setup do
    IO.puts("\n\n================\n\nsetup *SELF* #{inspect(self())}\n\n=================\n\n")
    :ok
  end


  describe "data in to data out" do
    @tag :focus
    test "check for basic functionality", state do
      DirectDebug.info("starting 'check for basic functionality': #{inspect(state)}")
      resource_id = Nanoid.generate(8, @alphabet)
      run_id = Nanoid.generate(8, @alphabet)
      agent_ids = ["A"]
      encoded_pid = self() |> :erlang.term_to_binary() |> Base.encode64()

      # initialize the scenario
      start_scenario(resource_id, run_id, agent_ids, 1)

      actuator_number = 0

      # send a sensor data batch
      resp = GenServer.call(:TestingSimulator, {:send_sensor_data_batch, run_id, [{"A", [0, [0, 0, 0]]}], [encoded_pid]})
      DirectDebug.info("got the response: #{inspect(resp)}")

      # wait for an acknowledgment that it's started
      scenario_timeout = 3000
      receive do
          {:actuator_data, params} -> DirectDebug.extra("got actuator data - success")
          case params do
            %{"agent" => agent, "data" => data} ->
              assert agent == "A"
              case data do
                [actuator, [v1, v2]] ->
                  assert actuator == actuator_number
                  assert v1 != 0
                  assert v2 != 0
              end
          end
          msg -> DirectDebug.warning("received: #{inspect(msg)}")
      after
        scenario_timeout ->
          :timeout
          assert false, "scenario not created within #{scenario_timeout}ms"
      end

      assert resp == :ok
    end

    test "complex data set", state do
      DirectDebug.info("starting 'complex data set': #{inspect(state)}")
      resource_id = Nanoid.generate(8, @alphabet)
      run_id = Nanoid.generate(8, @alphabet)
      agent_ids = ["A", "B", "C", "D"]
      start_scenario(resource_id, run_id, agent_ids, 1)
      assert true
    end
  end

  def start_scenario(resource_id, run_id, agent_ids, actuators) do
    encoded_pid = self() |> :erlang.term_to_binary() |> Base.encode64()

    agents = Enum.map(agent_ids, & %{id: &1, actuators: actuators})

    DirectDebug.extra("agents: #{inspect(agents)}")
    # first, tell the sim to start the scenario
    resp = GenServer.call(:TestingSimulator,
      {:initiate_scenario_run,
        %{resource_id: Nanoid.generate(8, @alphabet),
          run_id: run_id,
          agents: agents,
          subscribers: [encoded_pid]
        }})
    DirectDebug.info("resp: #{inspect(resp)}")

    # wait for an acknowledgment that it's started
    scenario_timeout = 3000
    receive do
      _ -> IO.puts("WHAT THE ACTUAL FUCK!!")
      # The message will really be this `{:scenario_inited, _scenario_name, _pid} -> :ok`, but really any message at all is fine
      {:noreply, :ok}
    after
      scenario_timeout ->
        :timeout
        assert false, "scenario not created within #{scenario_timeout}ms"
    end

    DirectDebug.warning("Made it past the initialized scenario!!")


  end

  def handle_info(msg, state) do
    DirectDebug.warning("unknown message: #{inspect(msg)}")
  end
end

# good sample data set!!
# SimUdpConnector - HANDLING UDP INFO!!
# {"jsonrpc":"2.0","method":"batch","params":{"sensor_data":[{"agent":37597742525,"data":[1,[0.0029296875,13.0002136230469,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03155517578125,12.9987182617188,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.0318603515625,12.9984436035156,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03192138671875,12.9983825683594,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03192138671875,12.9983825683594,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[0,[22.7846908569336,97.3696975708008]],"scenario":"S7ZH5HH9"},{"agent":37698405825,"data":[0,[-93.4389495849609,-35.6253051757812]],"scenario":"S7ZH5HH9"},{"agent":37799069115,"data":[0,[77.8466491699219,-62.7686157226562]],"scenario":"S7ZH5HH9"}]}}"}
