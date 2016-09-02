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

  test "injects existing module definition even if not found in mapping" do
    assert Sample.not_mapped == "great"
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
  inject NotMapped

  def call_bar do
    Bar.bar
  end

  def call_other_bar do
    OtherBar.bar
  end

  def third_bar do
    BBar.bar
  end

  def not_mapped do
    NotMapped.great
  end
end

defmodule NotMapped do
  def great do
    "great"
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
