defmodule MockerOptions do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def store_settings(pid, module, setting) do
    GenServer.call(__MODULE__, {:store_settings, pid, module, setting})
  end

  def get_setting(pid, module) do
    GenServer.call(__MODULE__, {:get_settings, pid, module})
  end

  def handle_call({:store_settings, pid, module, setting}, _from, state) do
    module_settings = Map.get(state, pid, %{})
    module_settings = Map.put(module_settings, module, setting)
    state = Map.put(state, pid, module_settings)
    {:reply, {module, setting}, state}
  end

  def handle_call({:get_settings, pid, module}, _from, state) do
    module_settings = Map.get(state, pid, %{})
    setting = Map.get(module_settings, module)
    {:reply, setting, state}
  end
end
