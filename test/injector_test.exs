defmodule InjectorTest do
  use ExUnit.Case
  doctest Injector

  test "injects implementation" do
    assert Sample.call_bar == "bar"
  end

  test "injects different implementation for same module" do
    assert Sample.call_other_bar == "bar"
  end

  test "injects with alias" do
    assert Sample.third_bar == ThirdBar.bar
  end
end

defmodule MyMapping do
  def get_mapping do
    %{Bar: Bar, OtherBar: Bar, ABar: ThirdBar}
  end
end

defmodule Sample do
  use Injector, MyMapping
  inject Bar
  inject OtherBar
  inject ABar, as: BBar

  def call_bar do
    Bar.bar
  end

  def call_other_bar do
    OtherBar.bar
  end

  def third_bar do
    BBar.bar
  end
end

defmodule Bar do
  def bar do
    "bar"
  end
end

defmodule OtherBar do
  def bar do
    "other bar"
  end
end

defmodule ThirdBar do
  def bar do
    "third bar"
  end
end
