defmodule Foo do

  def go do
    MockBar.bar
  end

  def going do
    MockBaz.cat
  end

end

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

defmodule Mocked do

  defmacro __using__(_) do
    quote do
      use GenServer
      
      def start_link do
        GenServer.start_link(__MODULE__, %{call_count: %{}, interceptors: %{}})
      end
      
      def handle_call({:call_count, func, _args}, _from, %{call_count: call_count} = state) do
        count = Map.get(call_count, func, 0)
        {:reply, count, state}
      end

      def handle_call({:increment_call_count, func, _args}, _from, %{call_count: call_count} = state) do
        count = Map.get(call_count, func, 0)
        call_count = Map.put(call_count, func, count + 1)
        state = Map.put(state, :call_count, call_count)
        {:reply, state, state}
      end

      def handle_call({:set_interceptor, func, _args, intercept_func}, _from, %{interceptors: interceptors} = state) do
        interceptors_list = Map.get(interceptors, func, [])
        interceptors_list = interceptors_list ++ [intercept_func] 
        interceptors = Map.put(interceptors, func, interceptors_list)
        state = Map.put(state, :interceptors, interceptors) 
        {:reply, state, state}
      end

      def handle_call({:get_interceptor, func, _args}, _from, %{interceptors: interceptors} = state) do
        interceptors_list = Map.get(interceptors, func, [])
        {interceptor, interceptors_list} = get_next_interceptor(interceptors_list)

        interceptors = Map.put(interceptors, func, interceptors_list)
        state = Map.put(state, :interceptors, interceptors) 
 
        {:reply, interceptor, state}
      end

      defp get_next_interceptor([]), do: {nil, []}
      defp get_next_interceptor(list) when length(list) == 1, do: {list |> hd, list}
      defp get_next_interceptor([fun | tail]), do: {fun, tail}

      def call_interceptor(nil), do: nil
      def call_interceptor(interceptor), do: interceptor.()
    end
  end
end

defmodule MockBar do
  use Mocked

  def bar do
    GenServer.call(Mocker, {__MODULE__, :bar, nil, self})
    interceptor = GenServer.call(Mocker, {:get_interceptor, __MODULE__, :bar, nil, self})
    if(interceptor == :original_function) do
      "Actual impl"
    else
      call_interceptor(interceptor)
    end
  end

end

defmodule MockBaz do
  use Mocked

  def cat do
    GenServer.call(Mocker, {__MODULE__, :cat, nil, self}) 
    "do cat things"
  end
end

defmodule MockerTest do
  use ExUnit.Case, async: true
  doctest Injector
  import Mocker

  setup do
    Mocker.start_link
    :ok
  end

  test "should validate that Bar was called" do
    mock(MockBar)
    Foo.go
    assert was_called(MockBar, :bar) == once
  end

  test "should validate that Bar was called multiple times" do
    mock(MockBar)
    Foo.go
    Foo.go
    Foo.go
    assert was_called(MockBar, :bar) == times(3)
  end

  test "should validate that bar was never called" do
    mock(MockBar)
    assert was_called(MockBar, :bar) == never
  end

  test "should validate multiple mocked modules" do
    mock(MockBar)
    mock(MockBaz)
    Foo.go
    Foo.going
    Foo.go

    assert was_called(MockBar, :bar) == twice
    assert was_called(MockBaz, :cat) == once
  end

  test "should intercept function" do
    mock(MockBar)
    assert Foo.go == nil
    intercept(MockBar, :bar, nil, with: fn -> "intercepted" end)
    assert Foo.go == "intercepted"
  end

  test "should call original function only if instructed to do so" do
    mock(MockBar)
    intercept(MockBar, :bar, nil, with: :original_function)
    assert Foo.go == "Actual impl"
  end

  test "should call intercept functions in order" do
    mock(MockBar)
    intercept(MockBar, :bar, nil, with: fn -> "intercepted" end)
    intercept(MockBar, :bar, nil, with: fn -> "intercepted again" end)
    intercept(MockBar, :bar, nil, with: fn -> "intercepted a third time" end)
    intercept(MockBar, :bar, nil, with: fn -> "gets called from now on" end)

    assert Foo.go == "intercepted"
    assert Foo.go == "intercepted again"
    assert Foo.go == "intercepted a third time"
    assert Foo.go == "gets called from now on"
    assert Foo.go == "gets called from now on"
    assert Foo.go == "gets called from now on"
  end
end


