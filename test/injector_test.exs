defmodule InjectorBar do
  def bar do
    "bar"
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

  def call_bar do
    InjectorBar.bar
  end

  def third_bar do
    BBar.bar
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

end

