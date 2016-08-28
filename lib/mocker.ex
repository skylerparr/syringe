defmodule Mocker do
  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def mock(module) do
    {:ok, module_pid} = apply(module, :start_link, [])
    GenServer.call(__MODULE__, {:map_to_pid, self, module_pid, module})
  end

  def was_called(module, func, args \\ nil) do
    module_pid = GenServer.call(__MODULE__, {:get_module_pid, self, module})
    call_count = GenServer.call(module_pid, {:call_count, func, args})
    times(call_count)
  end

  def intercept(module, func, args, [with: intercept_func]) do
    module_pid = GenServer.call(__MODULE__, {:get_module_pid, self, module})
    GenServer.call(module_pid, {:set_interceptor, func, args, intercept_func})
  end

  def handle_call({:get_module_pid, test_pid, module}, _from, state) do
    module_pid = get_module_pid(state, module, test_pid)
    {:reply, module_pid, state}
  end

  def handle_call({:map_to_pid, test_pid, module_pid, module}, _from, state) do
    module_map = Map.get(state, test_pid, %{})
      |> Map.put(module, module_pid) 
    state = Map.put(state, test_pid, module_map) 
    {:reply, state, state}
  end
  
  def handle_call({:get_interceptor, module, func, args, test_pid}, _from, state) do
    module_pid = get_module_pid(state, module, test_pid)
    interceptor = GenServer.call(module_pid, {:get_interceptor, func, args})
    {:reply, interceptor, state}
  end

  def handle_call({module, func, args, test_pid}, _from, state) do
    module_pid = get_module_pid(state, module, test_pid)
    GenServer.call(module_pid, {:increment_call_count, func, args}) 
    {:reply, state, state}
  end

  defp get_module_pid(state, module, test_pid) do
    Map.get(state, test_pid)
      |> Map.get(module)
  end

  def never, do: :never  
  def once, do: :once
  def twice, do: :twice
  def times(0), do: never
  def times(1), do: once
  def times(2), do: twice
  def times(num) do
    "#{num} times" |> String.to_atom
  end
end


