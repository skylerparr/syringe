defmodule Foo do
  use Injector, Mapper
  inject Bar

  def go do
    Bar.cat
  end
end
