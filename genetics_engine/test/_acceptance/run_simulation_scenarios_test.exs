defmodule GeneticsEngine.Test.Acceptance.RunSimulationScenarios do
  use ExUnit.Case, async: false
#  import ExUnit.CaptureLog
#  import ExUnit.CaptureIO
  require DirectDebug

  alias GeneticsEngine.Test.TestSupport
  alias GeneticsEngine.Test.TestingSimulator
  alias GeneticsEngine.Test.MessageConfirmation

  @moduletag :external

  setup_all do
    opts =  %{
      send_ip: "127.0.0.1",
      # note the send/receive reversal; this is mimicking an external client
      send_port: Application.get_env(:genetics_engine, :receive_port, 7400),
      receive_port: Application.get_env(:genetics_engine, :send_port, 7401)
    }

    :pg.start_link()
    test_sim_pid = start_supervised!({TestingSimulator, opts})

    {:ok, %{test_sim: test_sim_pid}}
  end

  setup do
    :ok
  end

  defp is_nonzeroed_actuator(expected_actuator) do
    fn
      [actuator, [v1, v2]] ->
        assert actuator == expected_actuator
        assert v1 != 0
        assert v2 != 0
    end
  end

  # TODO: reactivate when actually required
#  defp is_zeroed_actuator(expected_actuator) do
#    fn
#      [actuator, [v1, v2]] ->
#        assert actuator == expected_actuator
#        assert v1 == 0
#        assert v2 == 0
#    end
#  end

  describe "data in to data out" do
    @tag :focus
    # implements: UCSC_1.1.2.2.1
    test "check for basic functionality - single agent, single sensor, single event", _state do
      DirectDebug.section("starting 'check for basic functionality'...")

      :pg.join(:scenario_events, self())
      :pg.join(:actuator_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = ["A"]

      # initialize the scenario
      TestSupport.start_scenario(resource_id, run_id, agent_ids, 1)

      actuator_number = 0

      # single, all-zero data event
      sensor_data_round_trip(run_id, [{"A", [0, [0, 0, 0]]}], :actuator_data, is_nonzeroed_actuator(actuator_number))

      # multiple data events that average to zero
      sensor_data_round_trip(run_id, [
        {"A", [0, [0, 0, 0]]},
        {"A", [0, [-1, -2, -3]]},
        {"A", [0, [1, 2, 3]]},
      ], :actuator_data, is_nonzeroed_actuator(actuator_number))

      # single data event that is not a zero vector
      sensor_data_round_trip(run_id, [{"A", [0, [1, 2, 3]]}], :no_action, is_nonzeroed_actuator(actuator_number))

      # multiple data events that do NOT average to zero
      sensor_data_round_trip(run_id, [
        {"A", [0, [0, 0, 0]]},
        {"A", [0, [1, 2, 3]]},
        {"A", [0, [2, 3, 4]]},
      ], :no_action, is_nonzeroed_actuator(actuator_number))
    end

    def sensor_data_round_trip(run_id, sensor_data_batch, expected_message, validation_func) do
      TestingSimulator.send_sensor_data_batch(run_id, sensor_data_batch)

      # wait for a confirmation that the resultant actuator response has been received by the testing sim (or no response has been generated)...
      evaluation_func = case expected_message do
        :actuator_data -> fn
                            {:actuator_data, params} -> {:ok, params}
                            msg -> {:error, msg}
                          end
        :no_action ->
          fn
                        :no_action -> {:ok, :no_action}
                        msg -> {:error, msg}
                      end
      end
      confirmation_data = MessageConfirmation.wait_for_confirmation(evaluation_func, "actuator response not received")

      # and validate the actual message received
      case confirmation_data do
        %{"agent" => agent, "data" => data} ->
          assert agent == "A"
          validation_func.(data)
        :no_action -> assert true
        {:error, msg} -> DirectDebug.error("bad confirmation response: #{inspect(msg)}")
          assert false, "expected message #{expected_message}; got #{inspect(msg)}"
      end
    end

    test "complex data set", state do
      DirectDebug.section("starting 'complex data set'")
      DirectDebug.extra("'complex data set' - state: #{inspect(state)}")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      agent_ids = ["A", "B", "C", "D"]
      TestSupport.start_scenario(resource_id, run_id, agent_ids, 1)
      # {"jsonrpc":"2.0","method":"batch","params":{"sensor_data":[{"agent":37597742525,"data":[1,[0.0029296875,13.0002136230469,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03155517578125,12.9987182617188,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.0318603515625,12.9984436035156,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03192138671875,12.9983825683594,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03192138671875,12.9983825683594,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[0,[22.7846908569336,97.3696975708008]],"scenario":"S7ZH5HH9"},{"agent":37698405825,"data":[0,[-93.4389495849609,-35.6253051757812]],"scenario":"S7ZH5HH9"},{"agent":37799069115,"data":[0,[77.8466491699219,-62.7686157226562]],"scenario":"S7ZH5HH9"}]}}"}


      assert true
    end
  end

  describe "start/stop scenarios" do
    test "start scenario" do
      DirectDebug.section("starting 'start scenario'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()

      %{pid: scenario_pid} = case TestSupport.start_scenario(resource_id, run_id, [], 1) do
        :error -> nil
        s -> s
      end

      assert Process.alive?(scenario_pid), "scenario process should be alive"
    end

    test "destroy scenario when sim quits" do
      DirectDebug.section("starting 'destroy scenario when sim quits'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()

      %{pid: scenario_pid} = case TestSupport.start_scenario(resource_id, run_id, [], 1) do
        :error -> nil
        s -> s
      end

      TestingSimulator.quit()

      MessageConfirmation.wait_for_confirmation(
        fn msg ->
          case msg do
            {:scenario_terminated, reason, scenario_details} -> DirectDebug.info("destroy scenario when sim quits - scenario terminated for reason '#{reason}': #{inspect(scenario_details)}")
                                                        {:ok, scenario_details}
            msg -> DirectDebug.warning("destroy scenario when sim quits - got msg: #{inspect(msg)}")
                   :error
          end
        end, "scenario termination confirmation not received", 2000)

      assert !Process.alive?(scenario_pid), "scenario process should NOT be alive"
    end

    test "auto stop scenario on all agents reaching target" do
      DirectDebug.section("starting 'auto stop scenario on all agents reaching target'...")

      :pg.join(:scenario_events, self())

      resource_id = TestSupport.make_resource_id()
      run_id = TestSupport.make_run_id()
      #      agent_ids = ["A", "B", "C", "D"]
#      agent_ids = ["A", "B"]
      agent_ids = ["A"]
      #      triggering_sensor_event_counts = [1,2,3,4]
      triggering_sensor_event_counts = [2]
      agent_params = Enum.zip([agent_ids, triggering_sensor_event_counts])

      %{pid: scenario_pid} = case TestSupport.start_scenario(resource_id, run_id, agent_ids, 1) do
        :error -> nil
        s -> s
      end

      DirectDebug.section("scenario_started: #{inspect(scenario_pid)}")

      TestSupport.make_complete_run_event_generator(run_id,
        agent_params,
        50).()

      case Process.whereis(:pg) do
        _ ->         MessageConfirmation.wait_for_confirmation(
                       fn msg ->
                         case msg do
                           {:scenario_terminated, scenario_details} -> DirectDebug.info("auto stop scenario on all agents reaching target - scenario terminated: #{inspect(scenario_details)}")
                                                                       {:ok, scenario_details}
                           msg -> DirectDebug.warning("auto stop scenario on all agents reaching target - got msg: #{inspect(msg)}")
                                  :error
                         end
                       end, "scenario termination confirmation not received", 2000)

      end

      assert !Process.alive?(scenario_pid), "scenario should have terminated"
      assert false
    end
  end

  def handle_info(msg, state) do
    DirectDebug.warning("unknown message: #{inspect(msg)}")
    {:noreply, state}
  end
end

# good sample data set!!
# SimUdpConnector - HANDLING UDP INFO!!
# {"jsonrpc":"2.0","method":"batch","params":{"sensor_data":[{"agent":37597742525,"data":[1,[0.0029296875,13.0002136230469,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03155517578125,12.9987182617188,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.0318603515625,12.9984436035156,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03192138671875,12.9983825683594,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[1,[0.03192138671875,12.9983825683594,0.0,-1.0]],"scenario":"S7ZH5HH9"},{"agent":37597742525,"data":[0,[22.7846908569336,97.3696975708008]],"scenario":"S7ZH5HH9"},{"agent":37698405825,"data":[0,[-93.4389495849609,-35.6253051757812]],"scenario":"S7ZH5HH9"},{"agent":37799069115,"data":[0,[77.8466491699219,-62.7686157226562]],"scenario":"S7ZH5HH9"}]}}"}
