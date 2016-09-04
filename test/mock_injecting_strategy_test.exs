defmodule MockingBar do
  def bar do
    "bar"
  end
end

defmodule MyService.Mock.Cool.Face.McBabar do
  def bar do
    "bar"
  end
end

defmodule Sample do
  use Injector
  inject MockingBar
  inject MyService.Mock.Cool.Face.McBabar, as: BBar

  def call_bar do
    MockingBar.bar
  end

  def third_bar do
    BBar.bar
  end

end

defmodule MockInjectingStrategyTest do
  use ExUnit.Case, async: false
  doctest Injector

  test "injects implementation" do
    assert Sample.call_bar == "bar"
  end

  test "injects with alias" do
    assert Sample.third_bar == "bar"
  end

  test "should create new module" do
    assert Injector.MockingBar.bar == "bar"
    assert Injector.MyService.Mock.Cool.Face.McBabar.bar == "bar"
  end
end

