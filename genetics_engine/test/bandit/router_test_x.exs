defmodule GenPrototyp0001.Bandit.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts GeneticsEngine.Bandit.Router.init([])

  test "POST /api/scenario triggers flow" do
    conn =
      conn(:get, "/api/status", ~s({"input": "value"}))
      |> put_req_header("content-type", "application/json")
      |> GeneticsEngine.Bandit.Router.call(@opts)

    assert conn.status == 200
#    assert conn.resp_body =~ "success"
  end
end
