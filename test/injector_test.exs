defmodule InjectorBar do
  def bar do
    "bar"
  end
end

defmodule One.Two.Three do
  def four do
    "4"
  end
end

defmodule MyService.Injector.Cool.Face.McBabar do
  def bar do
    "bar"
  end
end

defmodule InjectorSample do
  use Injector
  inject InjectorBar
  inject MyService.Injector.Cool.Face.McBabar, as: BBar
  inject One.Two.Three

  def call_bar do
    InjectorBar.bar
  end

  def third_bar do
    BBar.bar
  end

  def three do
    Three.four
  end
end

defmodule InjectorTest do
  use ExUnit.Case, async: true
  doctest Injector

  test "injects implementation" do
    assert InjectorSample.call_bar == "bar"
  end

  test "injects with alias" do
    assert InjectorSample.third_bar == "bar"
  end

  test "resolve alias correctly" do
    assert InjectorSample.three == "4"
  end
end

