defmodule GenePrototype0001.Features.ScenarioManagementTest do
  use Cabbage.Feature, async: false, file: "scenario_management.feature"
  @tag bdd: true

  setup_all do
    port = 4003
    start_supervised!({Bandit, plug: GenePrototype0001.Bandit.Router, scheme: :http, port: port})
    {:ok, base_url: "http://localhost:#{port}"}
  end

  setup do
    :ok
  end

  # All `defgiven/4`, `defwhen/4` and `defthen/4` takes a regex, matched data, state and lastly a block
  defgiven ~r/^The HTTP service is available$/, _, state do
    # `{:ok, state}` gets returned from each callback which updates the state or
    # leaves the state unchanged when something else is returned
#    {:ok, %{machine: Machine.put_coffee(Machine.new, number)}}
    {:ok, %{}}
  end

  defthen ~r/^Server status should be (?<server_status>true|false)$/, %{server_status: server_status}, %{base_url: url} do
    server_status = string_to_boolean(server_status)
    {:ok, resp} = Req.get(url <> "/api/status")
    assert resp.body["server"] == server_status
  end

  # =========================== HELPER FUNCTIONS =========================== #

  def string_to_boolean(str) do
    case str do
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end
end

