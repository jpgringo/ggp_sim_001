defmodule GeneticsEngine.Test.MessageConfirmation do
  @moduledoc false

  use ExUnit.Case

  @doc """
  waits for receipt of messages during the period defined by timeout and evaluates each received
  message using evaluation_func; evaluation_func must return either{:ok, parsed_or_raw_message},
  or `{:error, reason}` from every execution path
  """
  def wait_for_confirmation(evaluation_func, failure_msg \\ "confirmation not received", timeout \\ 3000) do
    start_time = System.monotonic_time(:millisecond)
     do_wait_for_confirmation(evaluation_func, failure_msg, timeout, start_time)
  end

  defp do_wait_for_confirmation(evaluation_func, failure_msg, timeout, start_time) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - start_time
    remaining = timeout - elapsed
    DirectDebug.warning("waiting for confirmation - rem=#{remaining}")

    if remaining <= 0 do
      assert false, "#{failure_msg} within #{timeout}ms"
    else
      receive do
        msg ->
          case evaluation_func.(msg) do
            {:ok, result} -> result
            _ -> do_wait_for_confirmation(evaluation_func, failure_msg, timeout, start_time)
          end
      after
        remaining ->
          assert false, "#{failure_msg} within #{timeout}ms"
      end
    end
  end


end
