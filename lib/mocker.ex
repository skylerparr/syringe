defmodule Mocker do
  use GenServer

  def start_link do
    MockPidMapServer.start_link
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def mock(module), do: mock(module, self())
  def mock(module, pid) do
    MockPidMapServer.map(self(), pid)
    map_pid = MockPidMapServer.get(self())
    module = get_injector_module(module)
    {:ok, module_pid} = apply(module, :start_mock_link, [])
    GenServer.call(__MODULE__, {:map_to_pid, map_pid, module_pid, module})
  end

  def was_called({module, func, args}), do: was_called(module, func, args)
  def was_called(module, func, args \\ []) do
    map_pid = MockPidMapServer.get(self())
    module = get_injector_module(module)
    module_pid = GenServer.call(__MODULE__, {:get_module_pid, map_pid, module})
    call_count = GenServer.call(module_pid, {:call_count, func, args})
    times(call_count)
  end

  def intercept(module, func, args, [with: intercept_func]) do
    orig_module = module
    map_pid = MockPidMapServer.get(self())
    module = get_injector_module(module)
    module_pid = GenServer.call(__MODULE__, {:get_module_pid, map_pid, module})
    GenServer.call(module_pid, {:set_interceptor, func, args, intercept_func})
    {orig_module, func, args}
  end

  defp get_injector_module(module) do
    module = module 
    |> Atom.to_string 
    |> String.split(".")
    |> tl 
    |> Enum.join(".")

    "Injector." <> module 
    |> String.to_atom
    |> Injector.as_elixir_module
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
  
  def handle_call({:get_interceptor, module, func, args, test_pid}, from, state) do
    module_pid = get_module_pid(state, module, test_pid)
    interceptor = cond do
      is_atom(test_pid) -> :original_function
      module_pid == nil -> find_ancestor_interceptor(module, func, args, from, state, test_pid)
      module_pid == nil && is_pid(test_pid) -> :original_function
      true -> GenServer.call(module_pid, {:get_interceptor, func, args})
    end
    {:reply, interceptor, state}
  end

  def handle_call({module, func, args, test_pid}, _from, state) do
    module_pid = get_module_pid(state, module, test_pid)
    if(module_pid != nil) do
      GenServer.call(module_pid, {:increment_call_count, func, args}) 
    end
    {:reply, state, state}
  end

  defp find_ancestor_interceptor(module, func, args, from, state, test_pid) do
    pid_info = Process.info(test_pid) || [dictionary: []]
    case pid_info |> Keyword.get(:dictionary, ["$ancestors": []]) |> Keyword.get(:"$ancestors") do
      nil -> :original_function
      ancestor_pids -> ancestor_pid = List.first(ancestor_pids)
                       {:reply, interceptor, _state} = handle_call({:get_interceptor, module, func, args, ancestor_pid}, from, state)
                       interceptor || :original_function
    end
  end

  defp get_module_pid(state, module, test_pid) do
    Map.get(state, test_pid, %{})
      |> Map.get(module)
  end

  def never, do: :never  
  def once, do: :once
  def twice, do: :twice
  def times(0), do: never()
  def times(1), do: once()
  def times(2), do: twice()
  def times(num) do
    "#{num} times" |> String.to_atom
  end

  def any, do: :any
end


