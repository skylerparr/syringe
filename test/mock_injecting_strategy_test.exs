defmodule MockingBar do
  def bar do
    "bar"
  end
end

defmodule One.Two.Three.Four do
  def four do
    "4"
  end
end

defmodule MyService.Mock.Cool.Face.McBabar do
  def bar do
    "bar"
  end
end

defmodule Sample do
  use Injector
  inject(MockingBar)
  inject(One.Two.Three.Four)
  inject(MyService.Mock.Cool.Face.McBabar, as: BBar)

  def call_bar do
    MockingBar.bar()
  end

  def third_bar do
    BBar.bar()
  end

  def four do
    Four.four()
  end
end

defmodule MockInjectingStrategyTest do
  use ExUnit.Case, async: true
  doctest Injector

  test "injects implementation" do
    assert Sample.call_bar() == "bar"
  end

  test "injects with alias" do
    assert Sample.third_bar() == "bar"
  end

  test "should create new module" do
    assert Injector.MockingBar.bar() == "bar"
    assert Injector.MyService.Mock.Cool.Face.McBabar.bar() == "bar"
  end

  test "resolve alias correctly" do
    assert Sample.four() == "4"
  end
end
