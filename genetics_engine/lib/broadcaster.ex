defmodule Broadcaster do
  @moduledoc false

  def broadcast(topic, message, data) do
    if Process.whereis(:pg) != nil do
      DirectDebug.warning("Broadcasting to #{topic} process group…")
      Enum.each(:pg.get_members(topic), & send(&1, {topic, message, data}))
    end
  end
end
