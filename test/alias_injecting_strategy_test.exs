defmodule AliasBar do
  def bar do
    "bar"
  end
end

defmodule One.Two.Three.Four.Five do
  def four do
    "4"
  end
end

defmodule MyService.Alias.Cool.Face.McBabar do
  def bar do
    "bar"
  end
end

defmodule AliasSample do
  use Injector
  inject AliasBar
  inject One.Two.Three.Four.Five
  inject MyService.Alias.Cool.Face.McBabar, as: BBar

  def call_bar do
    AliasBar.bar
  end

  def third_bar do
    BBar.bar
  end

  def four do
    Five.four
  end
end

defmodule AliasInjectingStrategyTest do
  use ExUnit.Case, async: false
  doctest Injector

  setup do
    Mix.env(:dev)
    on_exit fn -> 
      Mix.env(:test)
    end
    :ok
  end

  test "injects implementation" do
    assert AliasSample.call_bar == "bar"
  end

  test "injects with alias" do
    assert AliasSample.third_bar == "bar"
  end

  test "inject correct alias" do
    assert AliasSample.four == "4"
  end
end

