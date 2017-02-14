defmodule MockPidMapServerTest do
  use ExUnit.Case

  setup do
    MockPidMapServer.start_link
    :ok
  end

  test "should map pid" do
    {:ok, pid} = Task.start_link(fn() -> receive do end end)
    MockPidMapServer.map(self(), pid)
    assert MockPidMapServer.get(self()) == pid
  end
end
