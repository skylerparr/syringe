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

  def was_called(module, func, args) do
    module_pid = GenServer.call(__MODULE__, {:get_module_pid, self, module})
    call_count = GenServer.call(module_pid, {:call_count, func, args})
    times(call_count)
  end

  def handle_call({:get_module_pid, test_pid, module}, _from, state) do
    module_pid = Map.get(state, test_pid)
      |> Map.get(module)
    {:reply, module_pid, state}
  end

  def handle_call({:map_to_pid, test_pid, module_pid, module}, _from, state) do
    module_map = Map.get(state, test_pid, %{})
      |> Map.put(module, module_pid) 
    state = Map.put(state, test_pid, module_map) 
    {:reply, state, state}
  end

  def handle_call({module, func, args, test_pid}, _from, state) do
    module_pid = Map.get(state, test_pid)
      |> Map.get(module)
    GenServer.call(module_pid, {:increment_call_count, func, args}) 
    {:reply, state, state}
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
        GenServer.start_link(__MODULE__, %{})
      end
      
      def handle_call({:call_count, func, _args}, _from, state) do
        count = Map.get(state, func, 0)
        {:reply, count, state}
      end

      def handle_call({:increment_call_count, func, _args}, _from, state) do
        count = Map.get(state, func, 0)
        state = Map.put(state, func, count + 1)
        {:reply, state, state}
      end
    end
  end
end

defmodule MockBar do
  use Mocked

  def bar do
    GenServer.call(Mocker, {__MODULE__, :bar, [], self})
    "Actual impl"
  end

end

defmodule MockBaz do
  use Mocked

  def cat do
    GenServer.call(Mocker, {__MODULE__, :cat, [], self}) 
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
    assert was_called(MockBar, :bar, nil) == once
  end

  test "should validate that Bar was called multiple times" do
    mock(MockBar)
    Foo.go
    Foo.go
    Foo.go
    assert was_called(MockBar, :bar, nil) == times(3)
  end

  test "should validate that bar was never called" do
    mock(MockBar)
    assert was_called(MockBar, :bar, nil) == never
  end

  test "should validate multiple mocked modules" do
    mock(MockBar)
    mock(MockBaz)
    Foo.go
    Foo.going
    Foo.go

    assert was_called(MockBar, :bar, nil) == twice
    assert was_called(MockBaz, :cat, nil) == once
  end
end


