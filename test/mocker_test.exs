defmodule Foo do

  def go do
    MockBar.bar
  end

  def going do
    MockBaz.cat
  end

  def gone(a, b, c) do
    MockBar.with_args(a, b, c)
  end
end

defmodule MockBar do
  use Mocked

  def bar do
    mock_func(__MODULE__, :bar, nil, fn() -> 
      "Actual impl"
    end)
  end

  def with_args(a, b, c) do
    mock_func(__MODULE__, :with_args, [a,b,c], fn(a,b,c) ->
      {a,b,c}
    end)
  end
end

defmodule MockBaz do
  use Mocked

  def cat do
    mock_func(__MODULE__, :cat, nil, fn() -> 
      "do cat things"
    end)
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
    assert was_called(MockBar, :with_args, ["a", {:b}, %{c: 1}]) == twice
    assert was_called(MockBar, :with_args, ["a", 100, %{c: 1}]) == once
    assert was_called(MockBar, :with_args, ["b", 100, %{c: 1}]) == never
  end

  test "should intercept with specific function arguments" do
    mock(MockBar)
    intercept(MockBar, :with_args, ["a", {:b}, %{c: 1}], with: :original_function)
    intercept(MockBar, :with_args, ["b", {:c}, %{d: 1}], with: fn(_,_,_) -> {"foo"} end)
    assert Foo.gone("a", {:b}, %{c: 1}) == {"a", {:b}, %{c: 1}}
    assert Foo.gone("b", {:c}, %{d: 1}) == {"foo"}
    assert Foo.gone("", "", "") == nil
    assert was_called(MockBar, :with_args, ["", "", ""]) == once
  end
end


