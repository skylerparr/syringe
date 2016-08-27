defmodule FooTest do
  use ExUnit.Case
  doctest Injector
  import Mocker

  test "should validate that Bar was called" do
    mock(MockBar)
    assert Foo.go == "I'm a test function"
  end

  test "should validate again" do
    assert Foo.go == "I'm a test function"
  end
end
