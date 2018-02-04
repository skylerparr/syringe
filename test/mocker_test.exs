defmodule MockBar do
  def bar do
    "Actual impl"
  end

  def with_args(a, b, c) do
    {a,b,c}
  end
end

defmodule MockBaz do
  def cat do
    "do cat things"
  end
end

defmodule MockedStruct do

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


defmodule Foo do
  use Injector
  inject MockBar
  inject MockBaz
  inject MockWorker
  inject MockedStruct
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

  def struct(_) do
    %MockedStruct{name: "foo", address: "bar"}
    |> MockedStruct.get_data
  end

  def call_delegate() do
    MockDelegate.do_delegate()
  end
end

defmodule Server do
  use GenServer
  use Injector

  inject Foo

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
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
    assert Foo.go == "Actual impl"
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
    assert Foo.gone("a", {:b}, %{c: 1}) == {"a", {:b}, %{c: 1}}
    assert Foo.gone("a", {:b}, %{c: 1}) == {"a", {:b}, %{c: 1}}
    assert Foo.gone("a", 100, %{c: 1}) == {"a", 100, %{c: 1}}
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
    assert Foo.gone("", "", "") == {"", "", ""}
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
    mock(MockedStruct)
    struct = %MockedStruct{name: "foo", address: "bar"}
    intercept(MockedStruct, :get_data, [any()], with: fn(_) -> "things" end)

    assert Foo.struct(struct) == "things"
    assert was_called(MockedStruct, :get_data, [struct]) == once()
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

  test "should be validate the intercepted call" do
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

  test "should call original_function by default" do
    mock(MockBaz)
    assert Foo.going == "do cat things"
  end

end


