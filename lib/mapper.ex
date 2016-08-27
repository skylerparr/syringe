defmodule Mapper do

  def get_mapping do
    get_map(Mix.env)
  end

  def get_map(:test) do
    %{Bar: MockBar}
  end

  def get_map(_) do
    %{Bar: Bar}
  end

end

