defmodule MockBar do
  def bar do
    "Actual impl"
  end

  def with_args(a, b, c) do
    {a,b,c}
  end

  def with_args(a) do
    a
  end

  def with_optional_args(a, b \\ 0) do
    {a, b}
  end
end

defmodule MockBaz do
  def cat do
    "do cat things"
  end

  if Mix.env() == :test do
    def meow() do
      "the cat says meow"
    end
  else
    def meow() do
      "the cat only says meow in test"
    end
  end
end

defmodule Mocker.MockedStruct do

  defstruct name: nil, address: nil

  def get_data(struct) do
    struct
  end

end

defmodule MockDelegate do
  defdelegate do_delegate(), to: MockDel
end

defmodule MockDel do
  def do_delegate() do
    "foo"
  end
end

defmodule MockTasks do
  use Injector
  inject Task

  def run_tasks() do
    task2 = Task.async(fn() ->
      Task.async(__MODULE__, :run, ["foo"])
      "bar"
    end)

    task2
  end

  def run(arg) do
    arg
  end
end

defmodule MockProcess do
  use Injector
  inject MockBaz

  def do_action() do
    {:ok, pid} = Agent.start(fn() -> nil end)
    Task.start(fn() ->
      Task.start_link(fn() ->
        Task.async(__MODULE__, :exec, [pid])
      end)
    end)
    pid
  end

  def exec(pid) do
    Agent.update(pid, fn(_) -> MockBaz.cat() end)
  end
end

defmodule Foo do
  use Injector
  inject MockBar
  inject MockBaz
  inject MockWorker
  inject Mocker.MockedStruct
  inject MockDelegate

  def go do
    MockBar.bar
  end

  def going do
    MockBaz.cat
  end

  def gone(a, b, c) do
    MockBar.with_args(a, b, c)
  end

  def pipe do
    MockBaz.cat
      |> MockBar.with_args(nil, nil)
  end

  def struct(_struct) do
    %Mocker.MockedStruct{name: "foo", address: "bar"}
    |> MockedStruct.get_data
  end

  def call_delegate() do
    MockDelegate.do_delegate()
  end

  def meow() do
    MockBaz.meow()
  end
end

defmodule Server do
  use GenServer
  use Injector

  inject Foo

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def call_foo do
    GenServer.call(__MODULE__, :call_foo)
  end

  def handle_call(:call_foo, _from, state) do
    Foo.go
    {:reply, state, state}
  end
end

defprotocol MyProto do
  def handle_work(data)
end

defimpl MyProto, for: Map do
  def handle_work(_data) do
    "bad"
  end
end

defimpl MyProto, for: List do
  def handle_work(_data) do
    "bad list"
  end
end

defmodule UseProtocol do
  use Injector
  inject MyProto

  def do_things(data) do
    MyProto.handle_work(data)
  end
end

defmodule MyGenServer do
  use Injector
  use GenServer

  inject Application
  inject MockBar
  inject Task

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Task.start_link(&break_cache/0)
    {:ok, nil}
  end

  def break_cache() do
    poll_time_ms() |> :timer.sleep()
    MockBar.bar()
    break_cache()
  end

  defp poll_time_ms() do
    (Application.get_env(:core_data, :poll_time_ms) || "0") |> String.to_integer()
  end
end

defmodule MockerTest do
  use ExUnit.Case, async: true
  doctest Mocker
  import Mocker

  test "should call origin function if not mocked" do
    assert Foo.go == "Actual impl"
  end

  test "should validate that Bar was called" do
    mock(MockBar)
    Foo.go
    assert was_called(MockBar, :bar) == once()
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
    assert was_called(MockBar, :bar) == never()
  end

  test "should validate multiple mocked modules" do
    mock(MockBar)
    mock(MockBaz)
    Foo.go
    Foo.going
    Foo.go

    assert was_called(MockBar, :bar) == twice()
    assert was_called(MockBaz, :cat) == once()
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

  test "should intercept multiple modules" do
    mock(MockBar)
    mock(MockBaz)
    intercept(MockBar, :bar, nil, with: fn -> "intercepted" end)
    intercept(MockBaz, :cat, nil, with: fn -> "intercepted cat" end)
    assert Foo.go == "intercepted"
    assert Foo.going == "intercepted cat"
  end

  test "should allow original function in intercepted functions" do
    mock(MockBar)
    intercept(MockBar, :bar, nil, with: fn -> "intercepted" end)
    intercept(MockBar, :bar, nil, with: fn -> "intercepted again" end)
    intercept(MockBar, :bar, nil, with: :original_function)
    intercept(MockBar, :bar, nil, with: fn -> "gets called from now on" end)

    assert Foo.go == "intercepted"
    assert Foo.go == "intercepted again"
    assert Foo.go == "Actual impl"
    assert Foo.go == "gets called from now on"
    assert Foo.go == "gets called from now on"
  end

  test "should assert was called with specific arguments" do
    mock(MockBar)
    assert Foo.gone("a", {:b}, %{c: 1}) == nil
    assert Foo.gone("a", {:b}, %{c: 1}) == nil
    assert Foo.gone("a", 100, %{c: 1}) == nil
    assert was_called(MockBar, :with_args, ["a", {:b}, %{c: 1}]) == twice()
    assert was_called(MockBar, :with_args, ["a", 100, %{c: 1}]) == once()
    assert was_called(MockBar, :with_args, ["b", 100, %{c: 1}]) == never()
  end

  test "should intercept with specific function arguments" do
    mock(MockBar)
    intercept(MockBar, :with_args, ["a", {:b}, %{c: 1}], with: :original_function)
    intercept(MockBar, :with_args, ["b", {:c}, %{d: 1}], with: fn(_,_,_) -> {"foo"} end)
    assert Foo.gone("a", {:b}, %{c: 1}) == {"a", {:b}, %{c: 1}}
    assert Foo.gone("b", {:c}, %{d: 1}) == {"foo"}
    assert Foo.gone("", "", "") == nil
    assert was_called(MockBar, :with_args, ["", "", ""]) == once()
  end

  test "should mock multiple functions and have them work together" do
    mock(MockBar)
    mock(MockBaz)
    intercept(MockBaz, :cat, nil, with: fn() -> "I'm a flying cat!" end)
    intercept(MockBar, :with_args, ["I'm a flying cat!", nil, nil], with: fn(a, _, _) -> "#{a} So am I" end)
    assert Foo.pipe == "I'm a flying cat! So am I"
  end

  test "should match with any" do
    mock(MockBar)
    intercept(MockBar, :with_args, ["a", 100, any()], with: :original_function)
    assert Foo.gone("a", 100, %{}) == {"a", 100, %{}}
    assert Foo.gone("a", 100, []) == {"a", 100, []}
    assert was_called(MockBar, :with_args, ["a", 100, any()]) == twice()
    assert was_called(MockBar, :with_args, ["a", 200, any()]) == never()
  end

  test "should call mocked function inside another process" do
    {:ok, pid} = Server.start_link
    mock(Foo, pid)
    intercept(Foo, :go, nil, with: fn() -> :ok end)
    Server.call_foo
    assert was_called(Foo, :go, nil) == once()
  end

  test "should not mock structs" do
    mock(Mocker.MockedStruct)
    struct = %Mocker.MockedStruct{name: "foo", address: "bar"}
    intercept(Mocker.MockedStruct, :get_data, [any()], with: fn(_) -> "things" end)

    assert Foo.struct(struct) == "things"
    assert was_called(Mocker.MockedStruct, :get_data, [struct]) == once()
  end

  test "should mock protocols" do
    data = %{foo: "bar"}
    mock(MyProto)
    intercept(MyProto, :handle_work, [data], with: fn(_) -> "mock proto data" end)
    intercept(MyProto, :handle_work, [[]], with: :original_function)

    assert UseProtocol.do_things(data) == "mock proto data"
    assert UseProtocol.do_things([]) == "bad list"
    assert was_called(MyProto, :handle_work, [data]) == once()
  end

  test "should be able to validate the intercepted call" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    assert Foo.gone("a", 100, %{}) == {"a", 100, %{}}
    assert Foo.gone("a", 100, []) == {"a", 100, []}
    assert was_called(outcome) == twice()
  end

  test "should mock delegates" do
    mock(MockDelegate)
    outcome = intercept(MockDelegate, :do_delegate, [], with: :original_function)
    assert "foo" == Foo.call_delegate()
    assert was_called(outcome) == once()
  end

  test "should handle intercepting functions with different arity" do
    mock(Task)

    expect1 = intercept(Task, :async, [any()], with: fn(fun) ->
      result = fun.()
      assert result == "bar"
    end)
    expect2 = intercept(Task, :async, [MockTasks, :run, any()], with: fn(mod, fun, args) ->
      result = apply(mod, fun, args)
      assert result == "foo"
    end)

    MockTasks.run_tasks()

    assert expect1 |> was_called() == once()
    assert expect2 |> was_called() == once()
  end

  test "should mock with nested processes" do
    mock(MockBaz)
    expectation = intercept(MockBaz, :cat, [], with: fn() -> "my intercepted data" end)
    agent_pid = MockProcess.do_action()
    :timer.sleep(10)
    assert Agent.get(agent_pid, fn(state) -> state end) == "my intercepted data"
    assert expectation |> was_called() == once()
  end

  test "should mock inside test processes" do
    mock(MockBaz)
    expectation = intercept(MockBaz, :cat, [], with: fn() -> "my intercepted data" end)
    task = Task.async(fn() ->
      MockProcess.do_action()
    end)
    :timer.sleep(10)
    {:ok, agent_pid} = Task.yield(task)
    assert Agent.get(agent_pid, fn(state) -> state end) == "my intercepted data"
    assert expectation |> was_called() == once()
  end

  test "should mock GenServer with named server" do
    MyGenServer.start_link()
  end

  test "should mock nested process inside GenServer" do
    MyGenServer.start_link()
    mock(MockBar)
    bar_call = intercept(MockBar, :bar, [], with: fn() -> "data" end)
    assert bar_call |> was_called() == once()
  end

  test "should not automock module if explicitly told not to do so" do
    mock(MockBaz)
    assert Foo.going() == nil

    mock(MockBaz, no_auto_mock: true)
    assert Foo.going() == "do cat things"
  end

  test "should mock a function that has conditional compilation" do
    mock(MockBaz)
    meow_call = intercept(MockBaz, :meow, [], with: fn() -> "mocked_meow" end)
    assert Foo.meow() == "mocked_meow"
    assert meow_call |> was_called() == once()
  end

  test "should validate a function was called at_least N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    assert outcome |> was_called() |> at_least(3) |> times()
  end

  test "should validate a function was called exactly N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    assert outcome |> was_called() |> at_least(3) |> times()
  end

  test "should fail if a function was not called at_least N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    refute outcome |> was_called() |> at_least(3) |> times()
  end

  test "should validate a function was called more_than N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    assert outcome |> was_called() |> more_than(3) |> times()
  end

  test "should fail if a function was called exactly N times and expecting more than N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    refute outcome |> was_called() |> more_than(3) |> times()
  end

  test "should validate a function was called at_most N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    assert outcome |> was_called() |> at_most(3) |> times()

    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    assert outcome |> was_called() |> at_most(3) |> times()
  end

  test "should fail if a function was called more times than allowed" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    refute outcome |> was_called() |> at_most(3) |> times()
  end

  test "should validate a function was called less_than N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    assert outcome |> was_called() |> less_than(3) |> times()
  end

  test "should fail if a function was called less_than N times and invoked more than N times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    refute outcome |> was_called() |> less_than(3) |> times()
  end

  test "should validate if a function was called between N and M times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, [])
    Foo.gone("a", 100, [])
    assert outcome |> was_called() |> between(3..4) |> times()
  end

  test "should fail if a function was not called between N and M times" do
    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, %{})
    refute outcome |> was_called() |> between(3..4) |> times()

    mock(MockBar)
    outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, %{})
    Foo.gone("a", 100, %{})
    refute outcome |> was_called() |> between(3..4) |> times()
  end

  test "should fail if the intercept api doesn't match the true api" do
    mock(MockBar)
    try do
      intercept(MockBar, :with_args, [any(), any()], with: :original_function)
      flunk("Should fail intercept")
    rescue
      _ in ExUnit.AssertionError ->
        flunk("Should fail intercept")
      _ in MockerApiError ->
        assert true
    end
  end

  test "should fail if the intercept api doesn't match the true api that has optional args" do
    mock(MockBar)
    try do
      intercept(MockBar, :with_optional_args, [any()], with: :original_function)
      intercept(MockBar, :with_optional_args, [any(), any()], with: :original_function)
      intercept(MockBar, :with_optional_args, [any(), any(), any()], with: :original_function)
      flunk("Should fail intercept")
    rescue
      _ in ExUnit.AssertionError ->
        flunk("Should fail intercept")
      _ in MockerApiError ->
        assert true
    end
  end
end


