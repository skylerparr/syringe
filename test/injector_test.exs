defmodule Bar do
  def bar do
    "bar"
  end
end

defmodule MyService.Cool.Face.McBabar do
  def bar do
    "bar"
  end
end

defmodule Sample do
  use Injector
  inject Bar
  inject MyService.Cool.Face.McBabar, as: BBar

  def call_bar do
    Bar.bar
  end

  def third_bar do
    BBar.bar
  end

end

defmodule InjectorTest do
  use ExUnit.Case, async: true
  doctest Injector

  test "injects implementation" do
    assert Sample.call_bar == "bar"
  end

  test "injects with alias" do
    assert Sample.third_bar == "bar"
  end

end

