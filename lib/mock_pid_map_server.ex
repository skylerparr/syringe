defmodule MockPidMapServer do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def map(key_pid, map_to_pid) do
    GenServer.call(__MODULE__, {:map, key_pid, map_to_pid})
  end

  def get(key_pid) do
    GenServer.call(__MODULE__, {:get, key_pid})
  end

  def handle_call({:map, key_pid, map_to_pid}, _from, map) do
    {:reply, map_to_pid, Map.put(map, key_pid, map_to_pid)}
  end

  def handle_call({:get, key_pid}, _from, map) do
    {:reply, Map.get(map, key_pid), map}
  end
end
